module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module SchemaStatements # :nodoc:

      # Adds a new index to the table.  +column_name+ can be a single Symbol, or
      # an Array of Symbols.
      #
      # ====== Creating a partial index
      #  add_index(:accounts, [:branch_id, :party_id], :unique => true, :where => "active")
      # generates
      #  CREATE UNIQUE INDEX index_accounts_on_branch_id_and_party_id ON accounts(branch_id, party_id) WHERE active
      #
      def add_index(table_name, column_name, options = {})
        index_name, index_type, index_columns, index_options = add_index_options(table_name, column_name, options)
        execute "CREATE #{index_type} INDEX #{quote_column_name(index_name)} ON #{quote_table_name(table_name)} (#{index_columns})#{index_options}"
      end

      # Checks to see if an index exists on a table for a given index definition.
      #
      # === Examples
      #  # Check that a partial index exists
      #  index_exists?(:suppliers, :company_id, :where => 'active')
      #
      #  # Note that index_exist? may return a false positive if the options passed in
      #  # are only a subset of a given index's options.  This does not differ from the Rails implementation
      #  # but may not be what is expected.
      #  # GIVEN: "index_suppliers_on_company_id" UNIQUE, btree (company_id) WHERE active
      #  index_exists?(:suppliers, :company_id, :where => 'active') => true
      #  index_exists?(:suppliers, :company_id, :unique => true) => true
      #
      def index_exists?(table_name, column_name, options = {})
        column_names = Array.wrap(column_name)
        index_name = options.key?(:name) ? options[:name].to_s : index_name(table_name, :column => column_names)

        # Always compare the index name
        default_comparator = lambda { |index| index.name == index_name }
        comparators = [default_comparator]

        # Add a comparator for each index option that is part of the query
        index_options = [:unique, :where]
        index_options.each do |index_option|
          comparators << lambda { |index| index.send(index_option) == options[index_option]} if options.key?(index_option)
        end

        # Search indexes for any that match all comparators
        indexes(table_name).any? do |index|
          comparators.inject(true) { |ret, comparator| ret && comparator.call(index) }
        end
      end

      # Returns options used to build out index SQL
      #
      # Added support for partial indexes implemented using the :where option
      #
      def add_index_options(table_name, column_name, options = {})
        column_names = Array(column_name)
        index_name   = index_name(table_name, :column => column_names)

        if Hash === options # legacy support, since this param was a string
          index_type = options[:unique] ? "UNIQUE" : ""
          index_name = options[:name].to_s if options.key?(:name)
          if supports_partial_index?
            index_options = options[:where] ? " WHERE #{options[:where]}" : ""
          end
        else
          index_type = options
        end

        if index_name.length > index_name_length
          raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' is too long; the limit is #{index_name_length} characters"
        end
        if index_name_exists?(table_name, index_name, false)
          raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' already exists"
        end
        index_columns = quoted_columns_for_index(column_names, options).join(", ")

        [index_name, index_type, index_columns, index_options]
      end
      protected :add_index_options

    end
  end
end