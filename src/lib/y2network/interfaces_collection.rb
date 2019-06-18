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
  #   iface = collection.by_name("eth0") #=> #<Y2Network::Interface:0x...>
  class InterfacesCollection
    # Objects of this class are able to keep a list of interfaces and perform simple queries
    # on such a list.
    #
    # @example Finding an interface by its name
    #   interfaces = Y2Network::InterfacesCollection.new([eth0, wlan0])
    #   interfaces.by_name("wlan0") # => wlan0
    #
    # @example FIXME (not implemented yet). For the future, we are aiming at this kind of API.
    #   interfaces = Y2Network::InterfacesCollection.new([eth0, wlan0])
    #   interfaces.of_type(:eth).to_a # => [eth0]

    extend Forwardable
    include Yast::Logger

    # @return [Array<Interface>] List of interfaces
    attr_reader :interfaces
    alias_method :to_a, :interfaces

    def_delegators :@interfaces, :each, :push, :<<, :reject!, :map, :flat_map, :any?

    # Constructor
    #
    # @param interfaces [Array<Interface>] List of interfaces
    def initialize(interfaces = [])
      @interfaces = interfaces
    end

    # @param bridge_iface [Interface] an interface of bridge type
    #
    # @return [Array<Interface>] list of interfaces usable in bridge_iface
    def select_bridgeable(bridge_iface)
      raise "Bridge interface expected" unless bridge_iface.type == "br"
      lan_items.select { |i| bridgeable?(bridge_iface, i) }
    end

    # @param bond_iface [Interface] an interface of bond type
    #
    # @return [Array<Interface>] list of interfaces usable in bridge_iface
    def select_bondable(bond_iface)
      raise "Bond interface expected" unless bond_iface.type == "bond"
      lan_items.select { |i| bondable?(bond_iface, i) }
    end

    # Returns an interface with the given name if present
    #
    # @todo It uses the hardware's name as a fallback if interface's name is not set
    #
    # @param name [String] Returns the interface with the given name
    # @return [Interface,nil] Interface with the given name or nil if not found
    def by_name(name)
      interfaces.find do |iface|
        iface_name = iface.name || iface.hwinfo.name
        iface_name == name
      end
    end

    # Deletes elements which meet a given condition
    #
    # @return [InterfacesCollection]
    def delete_if(&block)
      interfaces.delete_if(&block)
      self
    end

    # Compares InterfacesCollections
    #
    # @return [Boolean] true when both collections contain only equal interfaces,
    #                   false otherwise
    def ==(other)
      ((interfaces - other.interfaces) + (other.interfaces - interfaces)).empty?
    end

    alias_method :eql?, :==

  private

    # FIXME: this is only helper when coexisting with old LanItems module
    # can be used in new API of network-ng for read-only methods. It converts
    # old LanItems::Items into new Interface objects
    def lan_items
      Yast::LanItems.Items.map do |_index, item|
        name = item["ifcfg"] || item["hwinfo"]["dev_name"]
        Y2Network::Interface.new(name)
      end
    end

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
    # @param bond_iface [String] a name of an interface of bond type
    # @return list of names of interfaces enslaved in the bond_iface
    def bond_slaves(bond_iface)
      bond_map = Yast::NetworkInterfaces::FilterDevices("netcard").fetch("bond", {}).fetch(bond_iface, {})

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
      end

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

      true
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
