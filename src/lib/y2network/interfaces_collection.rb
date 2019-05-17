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

require "y2network/interface"
require "y2network/physical_interface"
require "y2network/virtual_interface"
require "forwardable"

module Y2Network
  # A container for network devices. In the end should implement methods for mass operations over
  # network interfaces like old LanItems::find_dhcp_ifaces.
  #
  # @example Create a new collection
  #   eth0 = Y2Network::Interface.new("eth0")
  #   collection = Y2Network::InterfacesCollection.new(eth0)
  #
  # @example Find an interface using its name
  #   iface = collection.find("eth0") #=> #<Y2Network::Interface:0x...>
  class InterfacesCollection
    # FIXME: Direct access to be replaced to make possible
    # Y2Network::Config.interfaces.eth0
    # Y2Network::Config.interfaces.of_type(:eth)
    # ...
    attr_reader :interfaces

    extend Forwardable
    include Yast::Logger

    def_delegators :@interfaces, :each, :map, :select

    # Constructor
    #
    # @param interfaces [Array<Interface>] List of interfaces
    def initialize(interfaces)
      @interfaces = interfaces
    end

    # @param name [String] Returns the interface with the given name
    def find(name)
      interfaces.find { |i| !i.name.nil? ? i.name == name : i.hardware.name }
    end

    # @param bridge_iface [Interface] an interface of bridge type
    #
    # @return [Array<Interface>] list of interfaces usable in bridge_iface
    def select_bridgeable(bridge_iface)
      raise "Bridge interface expected" unless bridge_iface.type == "br"
      interfaces.select { |i| bridgeable?(bridge_iface, i) }
    end

    # @param bond_iface [Interface] an interface of bond type
    #
    # @return [Array<Interface>] list of interfaces usable in bridge_iface
    def select_bondable(bond_iface)
      raise "Bond interface expected" unless bond_iface.type == "bond"
      interfaces.select { |i| bondable?(bond_iface, i) }
    end

    # Add an interface with the given name
    #
    # @param name [String] Interface's name
    def add(name)
      interfaces.push(Interface.new(name))
    end

    # Removes an interface with the given name from the collection
    #
    # @param name [String] Interface's name
    def remove(name)
      interfaces.delete_if { |i| i.name == name }
    end

    # Compares InterfacesCollections
    #
    # @return [Boolean] true when both collections contain only equal interfaces,
    #                   false otherwise
    def ==(other)
      @interfaces - other.interfaces && other.interfaces == @interfaces
    end

    alias_method :eql?, :==

  private

    # Creates a map where the keys are the interfaces enslaved and the values
    # are the bridges where them are taking part.
    def bridge_index
      index = {}

      bridge_devs = Yast::NetworkInterfaces.FilterDevices("netcard").fetch("br", {})

      bridge_devs.each do |bridge_master, value|
        value["BRIDGE_PORTS"].to_s.split.each do |if_name|
          index[if_name] = bridge_master
        end
      end

      index
    end

    # Creates list of devices enslaved in the bond device.
    #
    # @param bond_iface [Interface] a name of an nterface of bond type
    # @return list of names of interfaces enslaved in the bond_iface
    def bond_slaves(bond_iface)
      bond_map = Yast::NetworkInterfaces::Devices().fetch("bond", {}).fetch(bond_iface, {})

      bond_map.select { |k, _| k.start_with?("BONDING_SLAVE") }.values
    end

    def bond_index
      index = {}

      bond_devs = Yast::NetworkInterfaces.FilterDevices("netcard").fetch("bond", {})

      bond_devs.each do |bond_master, _value|
        bond_slaves(bond_master).each do |slave|
          index[slave] = bond_master
        end
      end

      log.debug("bond slaves index: #{index}")

      index
    end

    # Checks whether an interface can be bridged in particular bridge
    #
    # @param bridge_iface [Interface]
    # @param iface [Interface] an interface to be validated as the bridge_iface slave
    def bridgeable?(bridge_iface, iface)
      return true if !iface.configured

      if bond_index[iface.name]
        log.debug("Excluding (#{iface.name}) - is bonded")
        return false
      end

      # the iface is already in another bridge
      if bridge_index[iface.name] && bridge_index[devname] != bridge_iface.name
        log.debug("Excluding (#{iface.name}) - already bridged")
        return false
      else

      # exclude interfaces of type unusable for bridge
      case iface.type
      when "br"
        log.debug("Excluding (#{iface.name}) - is bridge")
        return false
      when "tun", "usb", "wlan"
        log.debug("Excluding (#{iface.name}) - is #{iface.type}")
        return false
      end

      case iface.startmode
      when "nfsroot"
        log.debug("Excluding (#{iface.name}) - is nfsroot")
        return false

      when "ifplugd"
        log.debug("Excluding (#{iface.name}) - ifplugd")
        return false
      end

      return true
    end

    # Checks whether an interface can be enslaved in particular bond interface
    #
    # @param bond_iface [Interface]
    # @param iface [Interface] an interface to be validated as bond_iface slave
    # TODO: Check for valid configurations. E.g. bond device over vlan
    # is nonsense and is not supported by netconfig.
    # Also devices enslaved in a bridge should be excluded too.
    def bondable?(bond_iface, iface)
      Yast.import "Arch"
      Yast.include self, "network/lan/s390.rb"

      # check if the device is L2 capable on s390
      if Yast::Arch.s390
        s390_config = s390_ReadQethConfig(iface.name)

        # only devices with L2 support can be enslaved in bond. See bnc#719881
        return false unless s390_config["QETH_LAYER2"] == "yes"
      end

      if bond_index[iface.name] && bond_index[iface.name] != bond_iface.name
        log.debug("Excluding (#{iface.name}) - is already bonded")
        return false
      end

      return true if !iface.configured

      iface.bootproto == "none"
    end
  end
end
