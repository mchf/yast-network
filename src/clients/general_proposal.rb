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
require "network/network_proposals"

module Yast
  class GeneralProposalClient < Client
    def main

      @args = WFM.Args

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("General network settings proposal started")
      Builtins.y2milestone("Arguments: %1", @args)

      network_proposals = NetworkProposals.instance

      @func = @args[0].to_s
      @param = @args[1].to_h

      # create a textual proposal
      case @func
        when "MakeProposal"
          @ret = {
            "preformatted_proposal" => network_proposals.text,
            "links"                 => network_proposals.links
          }

        when "AskUser"
          next_step = network_proposals.handle_link(@param["chosen_id"])
          @ret = { "workflow_sequence" => next_step }

        when "Description"
          @ret = network_proposals.heading

        when "Write"
          Builtins.y2debug("lan_proposal did it")
          @ret = {}
        else
          Builtins.y2error("unknown function: #{@func}")
          raise ArgumentError, "Unknown function: #{@func}"
      end

      Builtins.y2milestone("General network settings proposal finished (#{@ret})")
      Builtins.y2milestone("----------------------------------------")

      @ret

      # EOF
    end
  end
end

Yast::GeneralProposalClient.new.main
