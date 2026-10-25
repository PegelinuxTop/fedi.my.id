# frozen_string_literal: true

namespace :paradedb do
  desc 'Run migrations against dedicated PARADEDB_DATABASE_URL'
  task migrate: :environment do
    if ENV['PARADEDB_DATABASE_URL'].blank?
      puts 'PARADEDB_DATABASE_URL not set, running via standard db:migrate.'
      Rake::Task['db:migrate'].invoke
      next
    end

    puts "Migrating dedicated ParadeDB database at #{ENV['PARADEDB_DATABASE_URL']}..."
    connection = StatusSearchDocument.connection

    migration_file = Rails.root.join('db/migrate/20261025210000_create_status_search_documents.rb')
    require migration_file

    ActiveRecord::Migration.suppress_messages do
      CreateStatusSearchDocuments.new.exec_migration(connection, :up)
    end

    puts 'ParadeDB dedicated database migration complete.'
  end
end
