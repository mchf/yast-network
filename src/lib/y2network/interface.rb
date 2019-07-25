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
require "yast"

require "y2network/interface_type"
require "y2network/hwinfo"

module Y2Network
  # Network interface.
  class Interface
    # @return [String] Device name ('eth0', 'wlan0', etc.)
    attr_accessor :name
    # @return [String] Interface description
    attr_accessor :description
    # @return [InterfaceType] Interface type
    attr_accessor :type
    # @return [Boolean]
    attr_reader :configured
    # @return [HwInfo]
    attr_reader :hardware

    include Yast::Logger

    # Shortcuts for accessing interfaces' ifcfg options
    #
    # TODO: this makes Interface class tighly couplet to netconfig backend
    # once we have generic layer for accessing backends these methods has to be replaced
    ["STARTMODE", "BOOTPROTO"].each do |ifcfg_option|
      method_name = ifcfg_option.downcase

      define_method method_name do
        # when switching to new backend we need as much guards as possible
        if !configured || config.nil? || config.empty?
          raise "Trying to read configuration of an unconfigured interface #{@name}"
        end

        config[ifcfg_option]
      end
    end

    # Creates an instance of interface class based on the given interface type
    #
    # @param name [String] interface name (eth0, ...)
    # @param type [Y2Network::InterfaceType, String] interface type (InterfaceType::ETHERNET, ...)
    #                                                or its short name as a string
    def self.for(name, type)
      if type.is_a?(String)
        type = InterfaceType.from_short_name(type)

        raise ArgumentError, "Uknown type name: #{type}" if type.nil?
      end

      require "y2network/interfaces/#{type.file_name}"
      Interfaces.const_get(type.class_name).new(name, type: type)
    rescue LoadError => e
      log.info "Specialized interface class for #{type.short_name} not found. Fallbacking to default. #{e.inspect}"
      new(name, type: type)
    end

    # Constructor
    #
    # @param name [String] Interface name (e.g., "eth0")
    def initialize(name, type: InterfaceType::ETHERNET)
      @name = name
      @description = ""
      @type = type
      # @hardware and @name should not change during life of the object
      @hardware = Hwinfo.new(name: name)

      init(name)
    end

    # Determines whether two interfaces are equal
    #
    # @param other [Interface] Interface to compare with
    # @return [Boolean]
    def ==(other)
      return false unless other.is_a?(Interface)
      name == other.name
    end

    # eql? (hash key equality) should alias ==, see also
    # https://ruby-doc.org/core-2.3.3/Object.html#method-i-eql-3F
    alias_method :eql?, :==

    # Complete configuration of the interface
    #
    # @return [Hash<String, String>] option, value hash map
    def config
      system_config(name)
    end

  private

    def system_config(name)
      Yast::NetworkInterfaces.devmap(name)
    end

    def init(name)
      @configured = false
      @configured = !system_config(name).nil? if !(name.nil? || name.empty?)
    end
  end
end
