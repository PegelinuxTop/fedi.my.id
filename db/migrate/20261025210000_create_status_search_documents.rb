# frozen_string_literal: true

class CreateStatusSearchDocuments < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute <<~SQL
        DO $$
        BEGIN
          CREATE EXTENSION IF NOT EXISTS pg_search;
        EXCEPTION WHEN OTHERS THEN
          RAISE NOTICE 'pg_search extension not available, proceeding without it';
        END $$;
      SQL

      create_table :status_search_documents, id: false, if_not_exists: true do |t|
        t.bigint :status_id, primary_key: true, null: false
        t.bigint :account_id, null: false
        t.string :account_domain
        t.text :searchable_text, null: false, default: ''
        t.string :tags, array: true, default: []
        t.string :language
        t.integer :visibility, null: false, default: 0
        t.boolean :indexable, null: false, default: false
        t.string :properties, array: true, default: []
        t.bigint :searchable_by, array: true, default: []
        t.datetime :status_created_at, null: false
        t.timestamps
      end

      add_index :status_search_documents, :account_id, if_not_exists: true
      add_index :status_search_documents, :searchable_by, using: 'gin', if_not_exists: true
      add_index :status_search_documents, :tags, using: 'gin', if_not_exists: true
      add_index :status_search_documents, :status_created_at, if_not_exists: true

      execute <<~SQL
        DO $$
        BEGIN
          IF EXISTS (SELECT 1 FROM pg_am WHERE amname = 'bm25') THEN
            CREATE INDEX IF NOT EXISTS index_status_search_documents_on_bm25 ON status_search_documents
            USING bm25 (
              status_id,
              searchable_text,
              tags,
              account_id,
              account_domain,
              language,
              visibility,
              indexable,
              properties,
              status_created_at,
              searchable_by
            ) WITH (key_field = 'status_id');
          END IF;
        END $$;
      SQL
    end
  end

  def down
    safety_assured do
      execute 'DROP INDEX IF EXISTS index_status_search_documents_on_bm25;'
      drop_table :status_search_documents, if_exists: true
    end
  end
end
