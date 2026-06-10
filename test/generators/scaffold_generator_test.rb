# frozen_string_literal: true

require "test_helper"

# Tests the views generator (the "template engine" — ruby_ui_scaffold:scaffold)
# in isolation, against a temp destination.
class ScaffoldGeneratorTest < Rails::Generators::TestCase
  tests RubyUiScaffold::Generators::ScaffoldGenerator

  destination File.expand_path("../tmp", __dir__)
  setup :prepare_destination

  def test_creates_view_files
    run_generator ["User", "name:string", "email:string", "admin:boolean", "bio:text", "birthday:date"]

    assert_file "app/views/users/index.rb"
    assert_file "app/views/users/show.rb"
    assert_file "app/views/users/new.rb"
    assert_file "app/views/users/edit.rb"
    assert_file "app/views/users/form.rb"
  end

  def test_views_use_namespaced_class_under_views_module
    run_generator ["User", "name:string"]

    assert_file "app/views/users/index.rb" do |c|
      assert_match(/class Views::Users::Index < Views::Base/, c)
    end
    assert_file "app/views/users/show.rb" do |c|
      assert_match(/class Views::Users::Show < Views::Base/, c)
    end
    assert_file "app/views/users/new.rb" do |c|
      assert_match(/class Views::Users::New < Views::Base/, c)
    end
    assert_file "app/views/users/edit.rb" do |c|
      assert_match(/class Views::Users::Edit < Views::Base/, c)
    end
    assert_file "app/views/users/form.rb" do |c|
      assert_match(/class Views::Users::Form < Views::Base/, c)
    end
  end

  def test_does_not_create_application_view
    run_generator ["User", "name:string"]
    refute File.exist?(File.join(destination_root, "app/views/application_view.rb")),
           "should not create ApplicationView — phlex:install creates Views::Base"
  end

  def test_does_not_create_initializer
    run_generator ["User", "name:string"]
    refute File.exist?(File.join(destination_root, "config/initializers/ruby_ui_scaffold.rb")),
           "should not create an initializer — relies on Rails default app/views autoload"
  end

  def test_form_uses_ruby_ui_components_for_each_type
    run_generator ["User", "name:string", "bio:text", "admin:boolean", "birthday:date"]

    assert_file "app/views/users/form.rb" do |c|
      # string -> Input type=text
      assert_match(/Input\(type: "text", id: "user_name", name: "user\[name\]", value: @user\.name\)/, c)
      # text -> Textarea
      assert_match(/Textarea\(rows: 4, id: "user_bio"/, c)
      # boolean -> hidden + Checkbox
      assert_match(/Checkbox\(id: "user_admin"/, c)
      # date -> ruby_ui DatePicker
      assert_match(/DatePicker\(id: "user_birthday", name: "user\[birthday\]", selected_date: @user\.birthday, label: nil\)/, c)
      # FormField wraps each
      assert_match(/FormField do/, c)
      # Labels
      assert_match(/FormFieldLabel\(for: "user_name"\)/, c)
      # Errors
      assert_match(/FormFieldError do/, c)
      # Submit button (with a lucide icon: plus when new, check when editing)
      assert_match(/Button\(type: "submit", class: "gap-2"\) do/, c)
      assert_match(/lucide_icon\(@user\.new_record\? \? "plus" : "check", class: "size-4"\)/, c)
    end
  end

  # ---- default index: plain Table (no --datatable flag) ----

  def test_default_index_renders_plain_table
    run_generator ["User", "name:string", "email:string", "admin:boolean"]

    assert_file "app/views/users/index.rb" do |c|
      # No DataTable wrapper or toolbar
      refute_match(/DataTable\(/, c)
      refute_match(/DataTableToolbar/, c)
      refute_match(/DataTableSearch/, c)
      refute_match(/DataTablePerPageSelect/, c)
      refute_match(/DataTableSortHead/, c)
      refute_match(/DataTablePagination/, c)
      refute_match(/DataTablePaginationBar/, c)
      # Simple initialize — only the collection
      assert_match(/def initialize\(users:\)\n    @users = users\n  end/, c)
      refute_match(/page:/, c)
      refute_match(/per_page:/, c)
      refute_match(/total_count:/, c)
      refute_match(/search:/, c)
      refute_match(/sort:/, c)
      refute_match(/direction:/, c)
      # No private helpers from DataTable path
      refute_match(/def query_params/, c)
      refute_match(/def preserved_search_params/, c)
      # But still has shared structure
      assert_match(/Table\(class: "table-fixed"\)/, c)
      assert_match(/h-dvh w-full overflow-y-auto/, c)
      assert_match(/lucide_icon\("more-horizontal"/, c)
      assert_match(/AlertDialog\(class: "w-full"\) do/, c)
      # Plain TableHead for each column (no SortHead)
      assert_match(/TableHead { "Name" }/, c)
      assert_match(/TableHead { "Email" }/, c)
    end
  end

  def test_default_controller_index_is_simple
    run_generator ["User", "name:string", "email:string"]

    # The views generator alone doesn't emit the controller, but Rails routes
    # the scaffold_controller through us via hook_for. Asserting only what
    # our views generator emits — the controller is tested via end-to-end in
    # dummy apps. Here we just confirm the view contract matches simple mode.
    assert_file "app/views/users/index.rb" do |c|
      assert_match(/def initialize\(users:\)/, c)
    end
  end

  def test_index_renders_data_table_with_ruby_ui_components
    run_generator ["User", "name:string", "admin:boolean", "--datatable"]

    assert_file "app/views/users/index.rb" do |c|
      assert_match(/class Views::Users::Index < Views::Base/, c)
      # New initializer signature with pagination/search/sort state
      assert_match(/def initialize\(users:, page:, per_page:, total_count:, search: nil, sort: nil, direction: nil\)/, c)
      # Centered max-width layout
      assert_match(/mx-auto max-w-7xl/, c)
      # DataTable wrapper
      assert_match(/DataTable\(id: "users_data_table"\)/, c)
      assert_match(/DataTableToolbar do/, c)
      # Search input (string column present)
      assert_match(/DataTableSearch\(/, c)
      assert_match(/preserved_params: preserved_search_params/, c)
      # Per-page select
      assert_match(/DataTablePerPageSelect\(/, c)
      # Sortable name column -> DataTableSortHead
      assert_match(/DataTableSortHead\(/, c)
      assert_match(/column_key: "name"/, c)
      # Boolean rendered as Badge in body
      assert_match(/Badge\(variant: user\.admin\? \? "success" : "outline"\)/, c)
      # Pagination
      assert_match(/DataTablePaginationBar do/, c)
      assert_match(/DataTablePagination\(/, c)
      assert_match(/total_count: @total_count/, c)
      # Helpers
      assert_match(/def query_params/, c)
      assert_match(/def preserved_search_params/, c)
      # New link still there, now with a lucide `plus` icon
      assert_match(/new_user_path/, c)
      assert_match(/lucide_icon\("plus", class: "size-4"\)/, c)
      # Action column is now a DropdownMenu with a lucide `more-horizontal` trigger
      assert_match(/DropdownMenu\(options: \{ strategy: "fixed" \}\)/, c)
      assert_match(/DropdownMenuTrigger do/, c)
      assert_match(/lucide_icon\("more-horizontal", class: "size-5 cursor-pointer text-muted-foreground hover:text-foreground"\)/, c)
      # No Unicode-bullets fallback
      refute_match(/"•••"/, c)
      assert_match(/DropdownMenuContent\(class: "w-fit"\)/, c)
      assert_match(/DropdownMenuItem\(href: user_path\(user\)\) \{ "Show" \}/, c)
      assert_match(/DropdownMenuItem\(href: edit_user_path\(user\)\) \{ "Edit" \}/, c)
      assert_match(/DropdownMenuSeparator\(\)/, c)
      # Destructive delete is wrapped in AlertDialog (ruby_ui) — no JS confirm
      assert_match(/AlertDialog\(class: "w-full"\) do/, c)
      assert_match(/AlertDialogContent do/, c)
      assert_match(/class: "w-full justify-start text-destructive/, c)
      refute_match(/data_turbo_method/, c)
      refute_match(/data_turbo_confirm/, c)
    end
  end

  def test_injects_scaffold_helpers_into_components_base
    # Simulate `phlex:install` + `ruby_ui:install` having been run already —
    # the post-install base.rb only has `Routes` included.
    FileUtils.mkdir_p(File.join(destination_root, "app/components"))
    File.write(File.join(destination_root, "app/components/base.rb"), <<~RUBY)
      class Components::Base < Phlex::HTML
        include Phlex::Rails::Helpers::Routes
      end
    RUBY

    run_generator ["User", "name:string"]

    assert_file "app/components/base.rb" do |c|
      assert_match(/include Phlex::Rails::Helpers::FormWith/, c)
      assert_match(/include Phlex::Rails::Helpers::LinkTo/, c)
      assert_match(/include Phlex::Rails::Helpers::ButtonTo/, c)
      assert_match(/include Phlex::Rails::Helpers::Request/, c)
      assert_match(/register_output_helper :lucide_icon/, c)
    end
  end

  def test_helper_injection_is_idempotent
    # Pre-populate base.rb with all helpers already declared.
    FileUtils.mkdir_p(File.join(destination_root, "app/components"))
    File.write(File.join(destination_root, "app/components/base.rb"), <<~RUBY)
      class Components::Base < Phlex::HTML
        include Phlex::Rails::Helpers::Routes
        include Phlex::Rails::Helpers::FormWith
        include Phlex::Rails::Helpers::LinkTo
        include Phlex::Rails::Helpers::ButtonTo
        include Phlex::Rails::Helpers::Request
        register_output_helper :lucide_icon
      end
    RUBY

    run_generator ["User", "name:string"]

    contents = File.read(File.join(destination_root, "app/components/base.rb"))
    # Each line should appear exactly once — no duplicates from re-running.
    assert_equal 1, contents.scan(/include Phlex::Rails::Helpers::FormWith/).count
    assert_equal 1, contents.scan(/include Phlex::Rails::Helpers::LinkTo/).count
    assert_equal 1, contents.scan(/include Phlex::Rails::Helpers::ButtonTo/).count
    assert_equal 1, contents.scan(/include Phlex::Rails::Helpers::Request/).count
    assert_equal 1, contents.scan(/register_output_helper :lucide_icon/).count
  end

  def test_only_missing_helpers_are_injected
    # FormWith already there — others should still be added, FormWith not duplicated.
    FileUtils.mkdir_p(File.join(destination_root, "app/components"))
    File.write(File.join(destination_root, "app/components/base.rb"), <<~RUBY)
      class Components::Base < Phlex::HTML
        include Phlex::Rails::Helpers::Routes
        include Phlex::Rails::Helpers::FormWith
      end
    RUBY

    run_generator ["User", "name:string"]

    contents = File.read(File.join(destination_root, "app/components/base.rb"))
    assert_equal 1, contents.scan(/include Phlex::Rails::Helpers::FormWith/).count
    assert_match(/include Phlex::Rails::Helpers::LinkTo/, contents)
    assert_match(/include Phlex::Rails::Helpers::ButtonTo/, contents)
    assert_match(/include Phlex::Rails::Helpers::Request/, contents)
    assert_match(/register_output_helper :lucide_icon/, contents)
  end

  def test_index_omits_search_when_no_string_columns
    run_generator ["User", "age:integer", "admin:boolean", "--datatable"]

    assert_file "app/views/users/index.rb" do |c|
      refute_match(/DataTableSearch\(/, c)
      assert_match(/DataTablePerPageSelect\(/, c)
    end
  end

  def test_index_uses_table_fixed_and_truncates_text_cells
    run_generator ["User", "name:string", "email:string", "bio:text", "admin:boolean"]

    assert_file "app/views/users/index.rb" do |c|
      # table-fixed prevents auto-expanding column widths
      assert_match(/Table\(class: "table-fixed"\)/, c)
      # Action column is width-locked + nowrap so the dropdown stays visible
      assert_match(/TableHead\(class: "text-right whitespace-nowrap w-16"\) { "Actions" }/, c)
      assert_match(/TableCell\(class: "text-right whitespace-nowrap w-16"\) do/, c)
      # Text cells wrap content in a truncating div with title= for hover
      assert_match(/div\(class: "truncate", title: user_name_value\) { user_name_value }/, c)
      assert_match(/div\(class: "truncate", title: user_email_value\) { user_email_value }/, c)
      assert_match(/div\(class: "truncate", title: user_bio_value\) { user_bio_value }/, c)
      # Booleans are NOT wrapped (Badge component is small)
      refute_match(/div\(class: "truncate", title: user_admin/, c)
    end
  end

  def test_index_truncates_reference_label_too
    run_generator ["Book", "title:string", "author:references"]

    assert_file "app/views/books/index.rb" do |c|
      # Reference label is also wrapped in a truncating div
      assert_match(/div\(class: "truncate", title: book_author_label\) { book_author_label }/, c)
    end
  end

  def test_index_makes_non_text_non_blob_columns_sortable
    run_generator ["User", "name:string", "age:integer", "bio:text", "--datatable"]

    assert_file "app/views/users/index.rb" do |c|
      # Sortable: string, integer
      assert_match(/column_key: "name"/, c)
      assert_match(/column_key: "age"/, c)
      # NOT sortable: text -> plain TableHead
      assert_match(/TableHead { "Bio" }/, c)
      refute_match(/column_key: "bio"/, c)
    end
  end

  def test_references_attribute_emits_combobox_select_switch_in_form
    run_generator ["Book", "title:string", "author:references"]

    assert_file "app/views/books/form.rb" do |c|
      # Threshold constant declared at class level
      assert_match(/COMBOBOX_THRESHOLD = 100/, c)
      # Runtime switch based on parent's record count
      assert_match(/if Author\.count > COMBOBOX_THRESHOLD/, c)
      # Combobox branch
      assert_match(/Combobox do/, c)
      assert_match(/ComboboxSearchInput\(placeholder: "Search Author\.\.\."\)/, c)
      assert_match(/ComboboxRadio\(value: record\.id\.to_s, name: "book\[author_id\]"/, c)
      # Select branch (else)
      assert_match(/Select do/, c)
      assert_match(/SelectInput\(name: "book\[author_id\]", value: @book\.author_id\)/, c)
      # Both branches share the label fallback
      assert_match(/record\.try\(:name\) \|\| record\.try\(:title\)/, c)
      # Should NOT fall back to Input(type: "number")
      refute_match(/Input\(type: "number", id: "book_author_id"/, c)
    end
  end

  def test_form_without_references_does_not_declare_combobox_threshold
    run_generator ["User", "name:string", "email:string"]

    assert_file "app/views/users/form.rb" do |c|
      refute_match(/COMBOBOX_THRESHOLD/, c)
      refute_match(/Combobox/, c)
    end
  end

  def test_references_attribute_displays_assoc_name_in_index
    run_generator ["Book", "title:string", "author:references"]

    assert_file "app/views/books/index.rb" do |c|
      # The author column should show book.author.name (with fallback chain),
      # not book.author_id.
      assert_match(/book\.author&\.try\(:name\)/, c)
      assert_match(/book\.author&\.try\(:title\)/, c)
    end
  end

  def test_references_attribute_displays_assoc_name_in_show
    run_generator ["Book", "title:string", "author:references"]

    assert_file "app/views/books/show.rb" do |c|
      assert_match(/@book\.author&\.try\(:name\)/, c)
      assert_match(/@book\.author&\.try\(:title\)/, c)
    end
  end

  def test_destroy_uses_alert_dialog_by_default
    run_generator ["User", "name:string"]

    assert_file "app/views/users/index.rb" do |c|
      # AlertDialog is the default destroy UX (no JS browser confirm)
      assert_match(/AlertDialog\(class: "w-full"\) do/, c)
      assert_match(/AlertDialogTrigger\(class: "w-full"\)/, c)
      assert_match(/AlertDialogContent do/, c)
      assert_match(/AlertDialogTitle { "Delete User\?" }/, c)
      assert_match(/AlertDialogDescription do/, c)
      assert_match(/AlertDialogCancel { "Cancel" }/, c)
      # Form_with inside footer with method: :delete
      assert_match(/form_with\(url: user_path\(user\), method: :delete\)/, c)
      assert_match(/Button\(type: "submit", variant: "destructive"\) { "Delete" }/, c)
      # The old turbo-confirm path must NOT be emitted anymore
      refute_match(/data_turbo_method: :delete/, c)
      refute_match(/data_turbo_confirm/, c)
    end
  end

  # ---- --phlex-layout flag ----

  def test_default_views_do_not_wrap_in_a_phlex_layout
    run_generator ["User", "name:string"]

    %w[index show new edit].each do |view|
      assert_file "app/views/users/#{view}.rb" do |c|
        refute_match(/render\(\w+\) do$/, c)
      end
    end
  end

  def test_phlex_layout_flag_wraps_every_view
    run_generator ["User", "name:string", "--phlex-layout=ApplicationLayout"]

    %w[index show new edit].each do |view|
      assert_file "app/views/users/#{view}.rb" do |c|
        assert_match(/def view_template\n    render\(ApplicationLayout\) do\n/, c)
        # Closing `end` for the render block must exist (rough check: counts balance)
        assert c.scan(/^    end$/).any?, "Expected a closing `end` at view_template indent"
      end
    end
  end

  def test_show_renders_card_with_fields_and_centered_layout
    run_generator ["User", "name:string", "admin:boolean"]

    assert_file "app/views/users/show.rb" do |c|
      assert_match(/class Views::Users::Show < Views::Base/, c)
      assert_match(/def initialize\(user:\)/, c)
      assert_match(/mx-auto max-w-3xl/, c)
      # Card itself is narrower (max-w-prose) and centered within the wrapper
      assert_match(/Card\(class: "[^"]*max-w-prose[^"]*mx-auto/, c)
      assert_match(/Text\(weight: "medium"\) { "Name:" }/, c)
      # Boolean as Badge in show too
      assert_match(/Badge\(variant: @user\.admin\?/, c)
      # Edit link carries a lucide `pencil` icon
      assert_match(/Link\(href: edit_user_path\(@user\), variant: "outline", class: "gap-2"\) do/, c)
      assert_match(/lucide_icon\("pencil", class: "size-4"\)/, c)
    end
  end

  def test_form_has_submit_and_back_button
    run_generator ["Buddy", "name:string"]

    assert_file "app/views/buddies/form.rb" do |c|
      # Submit + Back live in one action row
      assert_match(/div\(class: "flex items-center gap-2"\) do/, c)
      assert_match(/Button\(type: "submit", class: "gap-2"\) do/, c)
      assert_match(/lucide_icon\(@buddy\.new_record\? \? "plus" : "check", class: "size-4"\)/, c)
      # Back goes to the referer, falling back to the index path
      assert_match(/Link\(href: request&\.referer \|\| buddies_path, variant: "ghost"\) \{ "Back" \}/, c)
    end
  end

  def test_form_is_narrow_and_centered_within_its_wrapper
    run_generator ["User", "name:string"]

    assert_file "app/views/users/form.rb" do |c|
      # `mx-auto` + `max-w-prose` centers the form within its parent so it
      # doesn't sit at the left edge of the wider page wrapper.
      assert_match(/form_with\([^)]*class: "[^"]*max-w-prose[^"]*mx-auto/, c)
    end
  end

  def test_new_and_edit_render_form_component_with_centered_layout
    run_generator ["User", "name:string"]

    assert_file "app/views/users/new.rb" do |c|
      assert_match(/render Views::Users::Form\.new/, c)
      assert_match(/url: users_path/, c)
      assert_match(/method: "post"/, c)
      assert_match(/mx-auto max-w-3xl/, c)
    end

    assert_file "app/views/users/edit.rb" do |c|
      assert_match(/render Views::Users::Form\.new/, c)
      assert_match(/url: user_path\(@user\)/, c)
      assert_match(/method: "patch"/, c)
      assert_match(/mx-auto max-w-3xl/, c)
    end
  end

  # ---- --literal flag ----

  def test_default_views_use_classic_initialize_not_literal_props
    run_generator ["User", "name:string"]

    %w[index show new edit form].each do |view|
      assert_file "app/views/users/#{view}.rb" do |c|
        assert_match(/def initialize/, c)
        refute_match(/^\s*prop :/, c)
      end
    end
  end

  def test_literal_flag_emits_prop_declarations_in_simple_views
    run_generator ["User", "name:string", "--literal"]

    assert_file "app/views/users/index.rb" do |c|
      assert_match(/^  prop :users, _Any$/, c)
      refute_match(/def initialize/, c)
    end

    %w[show new edit].each do |view|
      assert_file "app/views/users/#{view}.rb" do |c|
        assert_match(/^  prop :user, User$/, c)
        refute_match(/def initialize/, c)
      end
    end

    assert_file "app/views/users/form.rb" do |c|
      assert_match(/^  prop :user, User$/, c)
      assert_match(/^  prop :url, String$/, c)
      assert_match(/^  prop :method, String$/, c)
      refute_match(/def initialize/, c)
    end
  end

  def test_literal_with_datatable_emits_full_prop_set
    run_generator ["User", "name:string", "--datatable", "--literal"]

    assert_file "app/views/users/index.rb" do |c|
      assert_match(/^  prop :users, _Any$/, c)
      assert_match(/^  prop :page, Integer$/, c)
      assert_match(/^  prop :per_page, Integer$/, c)
      assert_match(/^  prop :total_count, Integer$/, c)
      assert_match(/^  prop :search, _Nilable\(String\), default: nil$/, c)
      assert_match(/^  prop :sort, _Nilable\(String\), default: nil$/, c)
      assert_match(/^  prop :direction, _Nilable\(String\), default: nil$/, c)
      refute_match(/def initialize/, c)
      # The DataTable view shell (toolbar, search, pagination) is still there
      assert_match(/DataTable\(id: "users_data_table"\)/, c)
    end
  end

  def test_literal_injects_extend_literal_properties_into_components_base
    FileUtils.mkdir_p(File.join(destination_root, "app/components"))
    File.write(File.join(destination_root, "app/components/base.rb"), <<~RUBY)
      class Components::Base < Phlex::HTML
        include Phlex::Rails::Helpers::Routes
      end
    RUBY

    run_generator ["User", "name:string", "--literal"]

    assert_file "app/components/base.rb" do |c|
      assert_match(/extend Literal::Properties/, c)
    end
  end

  def test_literal_extend_injection_is_idempotent
    FileUtils.mkdir_p(File.join(destination_root, "app/components"))
    File.write(File.join(destination_root, "app/components/base.rb"), <<~RUBY)
      class Components::Base < Phlex::HTML
        extend Literal::Properties
        include Phlex::Rails::Helpers::Routes
      end
    RUBY

    run_generator ["User", "name:string", "--literal"]

    contents = File.read(File.join(destination_root, "app/components/base.rb"))
    assert_equal 1, contents.scan(/extend Literal::Properties/).count
  end

  def test_no_literal_extend_when_flag_not_passed
    FileUtils.mkdir_p(File.join(destination_root, "app/components"))
    File.write(File.join(destination_root, "app/components/base.rb"), <<~RUBY)
      class Components::Base < Phlex::HTML
        include Phlex::Rails::Helpers::Routes
      end
    RUBY

    run_generator ["User", "name:string"]

    assert_file "app/components/base.rb" do |c|
      refute_match(/Literal::Properties/, c)
    end
  end

  # ---- auto-install when phlex/ruby_ui aren't detected ----

  # Drops a fake `bin/rails` into the destination that stands in for
  # `ruby_ui_scaffold:install` — it just writes the marker files the preflight
  # looks for. Lets us assert the preflight actually shells out to it.
  def stub_bin_rails!(body)
    bin = File.join(destination_root, "bin", "rails")
    FileUtils.mkdir_p(File.dirname(bin))
    File.write(bin, body)
    FileUtils.chmod(0o755, bin)
  end

  def test_auto_runs_install_when_setup_missing
    stub_bin_rails!(<<~SH)
      #!/usr/bin/env bash
      mkdir -p app/views app/components
      echo "class Views::Base < Phlex::HTML; end" > app/views/base.rb
      echo "class Components::Base < Phlex::HTML; include RubyUI; end" > app/components/base.rb
    SH

    run_generator ["User", "name:string"]

    # The stub installer ran (preflight shelled out to bin/rails)...
    assert_file "app/views/base.rb"
    assert_file "app/components/base.rb" do |c|
      assert_match(/include RubyUI/, c)
    end
    # ...and the scaffold still generated its views.
    assert_file "app/views/users/index.rb"
  end

  def test_skip_install_does_not_shell_out
    stub_bin_rails!(<<~SH)
      #!/usr/bin/env bash
      echo "class Views::Base < Phlex::HTML; end" > app/views/base.rb
    SH

    run_generator ["User", "name:string", "--skip-install"]

    # --skip-install means the installer must NOT have run...
    refute File.exist?(File.join(destination_root, "app/views/base.rb"))
    # ...but views are still generated (preflight only warns).
    assert_file "app/views/users/index.rb"
  end

  def test_no_auto_install_when_bin_rails_absent
    # No bin/rails in the destination — preflight can't shell out, so it just
    # warns and still generates the scaffold (pre-auto-install behavior).
    run_generator ["User", "name:string"]

    refute File.exist?(File.join(destination_root, "bin", "rails"))
    assert_file "app/views/users/index.rb"
  end

  # ---- on-demand component install (after files are written) ----

  # A bin/rails stub that satisfies the preflight install (writes the marker
  # files) and logs every `ruby_ui:component NAME` call to a file, so we can
  # assert exactly which components the scaffold installed.
  def stub_bin_rails_logging_components!
    stub_bin_rails!(<<~SH)
      #!/usr/bin/env bash
      case "$*" in
        *ruby_ui_scaffold:install*)
          mkdir -p app/views app/components
          echo "class Views::Base < Phlex::HTML; end" > app/views/base.rb
          echo "class Components::Base < Phlex::HTML; include RubyUI; end" > app/components/base.rb
          ;;
        *"ruby_ui:component"*)
          last="${@: -1}"
          echo "$last" >> installed_components.log
          ;;
      esac
    SH
  end

  def installed_components
    log = File.join(destination_root, "installed_components.log")
    File.exist?(log) ? File.read(log).split("\n").reject(&:empty?) : []
  end

  def test_installs_conditional_components_for_attributes
    stub_bin_rails_logging_components!

    run_generator ["User", "name:string", "admin:boolean", "bio:text", "birthday:date"]

    %w[badge checkbox textarea date_picker].each do |c|
      assert_includes installed_components, c, "Expected `#{c}` to be installed"
    end
    # The base shell is requested too (nothing pre-installed in this stub)
    assert_includes installed_components, "form"
    # No references → no combobox/select, no --datatable → no data_table
    refute_includes installed_components, "combobox"
    refute_includes installed_components, "data_table"
  end

  def test_installs_data_table_with_flag
    stub_bin_rails_logging_components!

    run_generator ["User", "name:string", "--datatable"]

    assert_includes installed_components, "data_table"
  end

  def test_installs_combobox_and_select_for_references
    stub_bin_rails_logging_components!

    run_generator ["Book", "title:string", "author:references"]

    assert_includes installed_components, "combobox"
    assert_includes installed_components, "select"
  end

  def test_skips_components_already_installed
    stub_bin_rails_logging_components!
    # Pretend `badge` is already present — it must not be re-installed.
    FileUtils.mkdir_p(File.join(destination_root, "app/components/ruby_ui/badge"))

    run_generator ["User", "admin:boolean"]

    refute_includes installed_components, "badge"
    # The other boolean component is still installed
    assert_includes installed_components, "checkbox"
  end

  def test_skip_install_installs_no_components
    stub_bin_rails_logging_components!

    run_generator ["User", "name:string", "admin:boolean", "--skip-install"]

    assert_empty installed_components
    # Views are still generated
    assert_file "app/views/users/index.rb"
  end
end
