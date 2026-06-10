# frozen_string_literal: true

module RubyUiScaffold
  # Shared helpers for generators that install ruby_ui components. Mixed into
  # both the install generator (base set) and the scaffold generator
  # (column/flag-specific set). Relies on the including class exposing
  # `destination_root` (every Rails generator does).
  module ComponentInstaller
    # A ruby_ui component is considered installed once its package directory
    # (or single-file component) exists under app/components/ruby_ui/. Guarding
    # on this is essential: `ruby_ui:component` copies files WITHOUT --force,
    # so re-installing a present component prompts interactively — which would
    # hang a non-interactive subprocess.
    def component_installed?(name)
      base = File.join(destination_root, "app/components/ruby_ui", name)
      Dir.exist?(base) || File.exist?("#{base}.rb")
    end

    # The subset of `names` not yet installed, preserving order.
    def uninstalled_components(names)
      names.reject { |name| component_installed?(name) }
    end
  end
end
