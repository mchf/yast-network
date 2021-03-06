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

require_relative "../../test_helper"
require_relative "../../support/connection_config_examples"
require "y2network/connection_config/tap"
require "y2network/interface_type"

describe Y2Network::ConnectionConfig::Tap do
  subject(:config) { described_class.new }

  include_examples "connection configuration"

  describe "#type" do
    it "returns 'tap'" do
      expect(config.type).to eq(Y2Network::InterfaceType::TAP)
    end
  end
end
