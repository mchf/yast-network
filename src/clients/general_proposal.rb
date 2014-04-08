# encoding: utf-8

#***************************************************************************
#
# Copyright (c) 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
#**************************************************************************
# File:	clients/general_proposal.ycp
# Package:	Network configuration
# Summary:	Network mode + ipv6 proposal
# Authors:	Martin Vidner <mvidner@suse.cz>
#
#
# This is not a standalone proposal, it depends on lan_proposal. It
# must run after it.
module Yast
  class GeneralProposalClient < Client
    def main
      textdomain "network"

      # The main ()
      @args = WFM.Args

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("General network settings proposal started")
      Builtins.y2milestone("Arguments: %1", @args)

      Yast.import "UI"
      Yast.import "Lan"
      Yast.import "LanItems"
      Yast.import "NetworkService"

      Yast.include self, "network/lan/complex.rb"


      @func = @args[0].to.s
      @param = @args[1].to_h
      @ret = {}

      # create a textual proposal
      case @func
        when "MakeProposal"
          @proposal = ""
          @links = []

          @sum = Lan.SummaryGeneral
          @proposal = @sum[0].to_s
          @links = @sum[1].to_a

          @ret = {
            "preformatted_proposal" => @proposal,
            "links"                 => @links,
          }
        # run the module
        when "AskUser"
          @chosen_id = @param["chosen_id"].to_s
          @seq = :next
          case @chosen_id
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

              @seq = ManagedDialog()
              Wizard.CloseDialog
          end
          LanItems.proposal_valid = false # repropose
          LanItems.SetModified
          @ret = { "workflow_sequence" => @seq }
        # create titles
        when "Description"
          @ret = {
            # RichText label
            "rich_text_title" => _("General Network Settings"),
            # Menu label
            "menu_title"      => _("General &Network Settings"),
            "id"              => "networkmode"
          }
        # write the proposal
        when "Write"
          Builtins.y2debug("lan_proposal did it")
        else
          Builtins.y2error("unknown function: #{@func}")
          raise ArgumentError, "Unknown function: #{@func}"
      end

      # Finish
      Builtins.y2milestone("General network settings proposal finished (#{@ret})")
      Builtins.y2milestone("----------------------------------------")

      @ret

      # EOF
    end
  end
end

Yast::GeneralProposalClient.new.main
