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
module Y2Network
  # Network interface.
  class Interface
    # @return [String] Device name (eth0, wlan0, etc.)
    attr_reader :name

    # Constructor
    #
    # @param name [String] Interface name (e.g., "eth0")
    def initialize(name)
      @name = name
    end

    # Determines whether two interfaces are equal
    #
    # @param other [Interface,:any] Interface to compare with
    # @return [Boolean]
    def ==(other)
      return false if other == :any
      name == other.name
    end

    alias_method :eql?, :==
  end
end