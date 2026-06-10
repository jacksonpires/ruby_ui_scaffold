# frozen_string_literal: true

module RubyUiScaffold
  # Shared helpers used by both the scaffold_controller and views generators
  # to identify which attributes participate in sort and search.
  module AttributeHelpers
    EXCLUDED_FROM_SORT = %i[text rich_text json jsonb binary attachment attachments].freeze

    # Columns we'll allowlist for sorting. Excludes large/blob types and
    # password digests, since sorting on them makes no sense.
    def sortable_columns
      attributes.reject { |a|
        EXCLUDED_FROM_SORT.include?(a.type) ||
          (a.respond_to?(:password_digest?) && a.password_digest?) ||
          (a.respond_to?(:attachment?) && (a.attachment? || a.attachments?))
      }.map(&:column_name)
    end

    # Only string columns are searchable via a LIKE clause. Excludes
    # password_digest. Boolean/integer/date columns aren't useful with LIKE.
    def searchable_columns
      attributes.select { |a|
        a.type == :string &&
          !(a.respond_to?(:password_digest?) && a.password_digest?)
      }.map(&:column_name)
    end

    # Non-polymorphic belongs_to attributes — used to:
    #   1. Eager-load via `scope.includes(*reference_associations)` in the controller
    #   2. Display friendly labels (assoc.name vs assoc_id) in index/show
    def reference_associations
      attributes.select do |a|
        a.respond_to?(:reference?) && a.reference? &&
          !(a.respond_to?(:polymorphic?) && a.polymorphic?)
      end.map { |a| a.name.to_sym }
    end
  end
end
