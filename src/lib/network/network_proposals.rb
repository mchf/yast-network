require "yast"

module Yast

  class NetworkProposals
    include Singleton
    include I18n

    Yast.import "UI"
    Yast.import "Lan"
    Yast.import "LanItems"
    Yast.import "NetworkService"

#    Yast.include self, "network/lan/complex.rb"

    PROPOSAL_ID = "networkmode"

    def caption
      textdomain "network"
      _("General Network Settings")
    end

    def menu_title
      textdomain "network"
      _("General &Network Settings")
    end

    def text
      read_proposals[0].to_s
    end

    def links
      read_proposals[1].to_a
    end

    def heading
      {
        "rich_text_title" => caption,
        "menu_title"      => menu_title,
        "id"              => PROPOSAL_ID
      }
    end

    def handle_link(link_id)
      raise ArgumentError, "Empty link id" if link_id.nil? || link_id.empty?

      ret = :next
      case link_id
        when "lan--nm-enable"
          NetworkService.use_network_manager
        when "lan--nm-disable"
          NetworkService.use_netconfig
        when "ipv6-enable"
          Lan.SetIPv6(true)
        when "ipv6-disable"
          Lan.SetIPv6(false)
        when "virtual-enable"
          Lan.virt_net_proposal = true
        when "virtual-revert"
          Lan.virt_net_proposal = false
        else
          Wizard.CreateDialog
          Wizard.SetDesktopTitleAndIcon("lan")

          ret = ManagedDialog()
          Wizard.CloseDialog
      end

      LanItems.proposal_valid = false # repropose
      LanItems.SetModified

      ret
    end

  private

    def read_proposals
      @@lan_proposals ||= Lan.SummaryGeneral
    end

  end
end
