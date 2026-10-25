# frozen_string_literal: true

require_relative 'base'

module Mastodon::CLI
  class Search < Base
    # Indices are sorted by amount of data to be expected in each, so that
    # smaller indices can go online sooner
    INDICES = [
      InstancesIndex,
      AccountsIndex,
      TagsIndex,
      PublicStatusesIndex,
      StatusesIndex,
    ].freeze

    option :concurrency, type: :numeric, default: 5, aliases: [:c], desc: 'Workload will be split between this number of threads'
    option :batch_size, type: :numeric, default: 100, aliases: [:b], desc: 'Number of records in each batch'
    option :only, type: :array, enum: %w(instances accounts tags statuses public_statuses status_search_documents), desc: 'Only process these indices'
    option :backend, type: :string, default: 'auto', desc: 'Search backend (elasticsearch or paradedb)'
    option :import, type: :boolean, default: true, desc: 'Import data from the database to the index'
    option :clean, type: :boolean, default: true, desc: 'Remove outdated documents from the index'
    option :reset_chewy, type: :boolean, default: false, desc: "Reset Chewy's internal index"
    option :only_mapping, type: :boolean, default: false, desc: 'Update the index specification without re-index'
    desc 'deploy', 'Create or upgrade Elasticsearch indices and populate them'
    long_desc <<~LONG_DESC
      If Elasticsearch is empty, this command will create the necessary indices
      and then import data from the database into those indices.

      This command will also upgrade indices if the underlying schema has been
      changed since the last run. Index upgrades erase index data.

      Even if creating or upgrading indices is not necessary, data from the
      database will be imported into the indices, unless overridden with --no-import.
    LONG_DESC
    def deploy
      if options[:backend] == 'paradedb' || (options[:backend] == 'auto' && SearchBackend.paradedb?)
        deploy_paradedb!
        return
      end

      verify_deploy_options!

      indices = if options[:only]
                  options[:only].map { |str| "#{str.camelize}Index".constantize }
                else
                  INDICES
                end

      pool      = Concurrent::FixedThreadPool.new(options[:concurrency], max_queue: options[:concurrency] * 10)
      importers = indices.index_with { |index| "Importer::#{index.name}Importer".constantize.new(batch_size: options[:batch_size], executor: pool) }
      progress  = ProgressBar.create(
        {
          total: nil,
          format: '%t%c/%u |%b%i| %e (%r docs/s)',
          autofinish: false,
        }.merge(progress_output_options)
      )

      Chewy::Stash::Specification.reset! if options[:reset_chewy]

      if options[:only_mapping]
        indices.select { |index| index.specification.changed? }.each do |index|
          progress.title = "Updating mapping for #{index} "
          index.update_specification
          index.specification.lock!
        end

        progress.title = 'Done! '
        progress.finish

        say('Updated index mappings', :green, true)
        return
      end

      # First, ensure all indices are created and have the correct
      # structure, so that live data can already be written
      indices.select { |index| index.specification.changed? }.each do |index|
        progress.title = "Upgrading #{index} "
        index.purge
        index.specification.lock!
      end

      progress.title = 'Estimating workload '
      progress.total = indices.sum { |index| importers[index].estimate! }

      reset_connection_pools!

      added   = 0
      removed = 0

      indices.each do |index|
        importer = importers[index]
        importer.optimize_for_import!

        importer.on_progress do |(indexed, deleted)|
          progress.total = nil if progress.progress + indexed + deleted > progress.total
          progress.progress += indexed + deleted
          added   += indexed
          removed += deleted
        end

        importer.on_failure do |reason|
          progress.log(pastel.red("Error while importing #{index}: #{reason}"))
        end

        if options[:import]
          progress.title = "Importing #{index} "
          importer.import!
        end

        if options[:clean]
          progress.title = "Cleaning #{index} "
          importer.clean_up!
        end
      ensure
        importer.optimize_for_search!
      end

      progress.title = 'Done! '
      progress.finish

      say("Indexed #{added} records, de-indexed #{removed}", :green, true)
    rescue Elastic::Transport::Transport::ServerError => e
      fail_with_message <<~ERROR
        There was an issue connecting to the search server. Make sure the
        server is configured and running correctly, and that the environment
        variable settings match what the server is expecting.

        #{e.message}
      ERROR
    end

    private

    def deploy_paradedb!
      say('Populating status_search_documents for ParadeDB...')
      scope = Status.unscoped.kept.without_reblogs
      progress = create_progress_bar(scope.count)

      scope.includes(:account, :tags, :media_attachments, :preloadable_poll)
           .find_in_batches(batch_size: options[:batch_size]) do |batch|
        batch.each do |status|
          StatusSearchDocument.refresh_for_status!(status)
          progress.increment
        rescue => e
          warn("Failed to index status #{status.id}: #{e.message}")
        end
      end

      if options[:clean]
        say('Cleaning up orphaned search documents...')
        if ENV['PARADEDB_DATABASE_URL'].present?
          # Cross-database cleanup: fetch valid IDs in batches
          valid_ids = Status.pluck(:id)
          StatusSearchDocument.where.not(status_id: valid_ids).delete_all
        else
          StatusSearchDocument.where.not(status_id: Status.select(:id)).delete_all
        end
      end

      say('ParadeDB status search documents populated successfully!', :green)
    end

    def verify_deploy_options!
      verify_deploy_concurrency!
      verify_deploy_batch_size!
    end

    def verify_deploy_concurrency!
      fail_with_message 'Cannot run with this concurrency setting, must be at least 1' if options[:concurrency] < 1
    end

    def verify_deploy_batch_size!
      fail_with_message 'Cannot run with this batch_size setting, must be at least 1' if options[:batch_size] < 1
    end

    def progress_output_options
      Rails.env.test? ? { output: ProgressBar::Outputs::Null } : {}
    end
  end
end
