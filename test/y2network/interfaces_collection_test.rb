# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.
require_relative "../test_helper"
require "y2network/interfaces_collection"

describe Y2Network::InterfacesCollection do
  subject(:collection) { described_class.new(interfaces) }

  let(:eth0) { Y2Network::Interface.new("eth0") }
  let(:wlan0) { Y2Network::Interface.new("wlan0") }
  let(:interfaces) { [eth0, wlan0] }

  describe "#find" do
    it "returns the interface with the given name" do
      expect(collection.find("eth0")).to eq(eth0)
    end
  end

  describe "#add" do
    it "adds an interface with the given name" do
      collection.add("eth1")
      eth1 = collection.find("eth1")
      expect(eth1.name).to eq("eth1")
    end
  end
end
