require "yast"
require "network/managed_dialog"

module Yast

  class NetworkProposals
    include Singleton
    include Logger
    include I18n

    Yast.import "UI"
    Yast.import "Lan"
    Yast.import "LanItems"
    Yast.import "NetworkService"

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
          ret = ManagedDialog.instance.run
      end

      LanItems.proposal_valid = false # repropose
      LanItems.SetModified

      ret
    end

    def write
      Yast.include self, "network/routines.rb"

      if PackagesInstall(Lan.Packages) != :next
        # popup already shown
        log.error("Packages installation failure, not saving")
      else
        Lan.virt_net_proposal = virt_proposal_required
        Lan.Propose
        Lan.WriteOnly
      end
    end

  private

    def read_proposals
      @@lan_proposals ||= Lan.SummaryGeneral
    end

    def remote_install
      Linuxrc.display_ip || Linuxrc.vnc || Linuxrc.usessh
    end

    # Decides if a proposal for virtualization host machine is required.
    def virt_proposal_required
      # S390 has special requirements. See bnc#817943
      return false if Arch.s390

      return true if PackageSystem.Installed("xen") && !Arch.is_xenU
      return true if PackageSystem.Installed("kvm")
      return true if PackageSystem.Installed("qemu")

      false
    end

  end
end
