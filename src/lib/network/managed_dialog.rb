require "yast"

module Yast

  Yast.import "Label"
  Yast.import "UI"

  class ManagedDialog

    include Singleton
    include UIShortcuts
    include Yast          # for fun_ref

    def run
      Yast.include self, "network/routines.rb" # for ReallyAbort
      Yast.include self, "network/widgets.rb"

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("lan")

      widget_descr = {
        "MANAGED" => managed_widget,
        "IPV6"    => ipv6_widget
      }

      contents = VBox(HSquash(VBox("MANAGED", VSpacing(0.5), "IPV6")))

      functions = { :abort => fun_ref(method(:ReallyAbort), "boolean ()") }

      ret = CWM.ShowAndRun(
        {
          "widget_descr"       => widget_descr,
          "contents"           => contents,
          # Network setup method dialog caption
          "caption"            => _("Network Setup Method"),
          "back_button"        => Label.BackButton,
          "abort_button"       => Label.CancelButton,
          "next_button"        => Label.OKButton,
          # #54027
          "disable_buttons"    => ["back_button"],
          "fallback_functions" => functions
        }
      )

      Wizard.CloseDialog

      # #148485: always show the device overview
      ret
    end

  end
end
