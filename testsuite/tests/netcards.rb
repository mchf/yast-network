# encoding: utf-8

module Yast
  class BridgeClient < Client
    def main
      Yast.import "Assert"
      Yast.import "Testsuite"

      @READ = {
        "network"   => {
          "section" => {
            "eth1"  => nil,
            "eth2"  => nil,
            "eth4"  => nil,
            "eth5"  => nil,
            "tun0"  => nil,
            "tap0"  => nil,
            "br0"   => nil,
            "bond0" => nil
          },
          "value"   => {
            "eth1"  => { "BOOTPROTO" => "none" },
            "eth2"  => { "BOOTPROTO" => "none" },
            "eth4"  => {
              "BOOTPROTO" => "static",
              "IPADDR"    => "0.0.0.0",
              "PREFIX"    => "32"
            },
            "eth5"  => { "BOOTPROTO" => "static", "STARTMODE" => "nfsroot" },
            "tun0"  => {
              "BOOTPROTO" => "static",
              "STARTMODE" => "onboot",
              "TUNNEL"    => "tun"
            },
            "tap0"  => {
              "BOOTPROTO" => "static",
              "STARTMODE" => "onboot",
              "TUNNEL"    => "tap"
            },
            "br0"   => { "BOOTPROTO" => "dhcp" },
            "bond0" => {
              "BOOTPROTO"      => "static",
              "BONDING_MASTER" => "yes",
              "BONDING_SLAVE0" => "eth1",
              "BONDING_SLAVE1" => "eth2"
            }
          }
        },
        "probe"     => {
          "architecture" => "i386",
          "netcard"      => [
            # yast2-network lists those as "Not configured" devices (no matching ifcfg files are defined)
            {
              "bus"            => "PCI",
              "bus_hwcfg"      => "pci",
              "class_id"       => 2,
              "dev_name"       => "eth11",
              "dev_names"      => ["eth11"],
              "device_id"      => 70914,
              "driver"         => "e1000e",
              "driver_module"  => "e1000e",
              "drivers"        => [
                {
                  "active"   => true,
                  "modprobe" => true,
                  "modules"  => [["e1000e", ""]]
                }
              ],
              "modalias"       => "pci:v00008086d00001502sv000017AAsd000021F3bc02sc00i00",
              "model"          => "Intel Ethernet controller",
              "old_unique_key" => "wH9Z.41x4AT4gee2",
              "resource"       => {
                "hwaddr" => [{ "addr" => "00:01:02:03:04:05" }],
                "io"     => [
                  {
                    "active" => true,
                    "length" => 32,
                    "mode"   => "rw",
                    "start"  => 24704
                  }
                ],
                "irq"    => [{ "count" => 0, "enabled" => true, "irq" => 20 }],
                "mem"    => [
                  {
                    "active" => true,
                    "length" => 131072,
                    "start"  => 4087349248
                  },
                  { "active" => true, "length" => 4096, "start" => 4087590912 }
                ]
              },
              "rev"            => "4",
              "slot_id"        => 25,
              "sub_class_id"   => 0,
              "sub_device_id"  => 74227,
              "sub_vendor"     => "Vendor",
              "sub_vendor_id"  => 7,
              "sysfs_bus_id"   => "0000:00:19.0",
              "sysfs_id"       => "/devices/pci0000:00/0000:00:19.0",
              "unique_key"     => "rBUF.41x4AT4gee2",
              "vendor"         => "Intel Corporation",
              "vendor_id"      => 98438
            },
            {
              "bus"            => "PCI",
              "bus_hwcfg"      => "pci",
              "class_id"       => 2,
              "dev_name"       => "eth12",
              "dev_names"      => ["eth12"],
              "device_id"      => 70914,
              "driver"         => "e1000e",
              "driver_module"  => "e1000e",
              "drivers"        => [
                {
                  "active"   => true,
                  "modprobe" => true,
                  "modules"  => [["e1000e", ""]]
                }
              ],
              "modalias"       => "pci:v00008086d00001502sv000017AAsd000021F3bc02sc00i00",
              "model"          => "Intel Ethernet controller",
              "old_unique_key" => "wH9Z.41x4AT4gee2",
              "resource"       => {
                "hwaddr" => [{ "addr" => "00:11:12:13:14:15" }],
                "io"     => [
                  {
                    "active" => true,
                    "length" => 32,
                    "mode"   => "rw",
                    "start"  => 24704
                  }
                ],
                "irq"    => [{ "count" => 0, "enabled" => true, "irq" => 20 }],
                "mem"    => [
                  {
                    "active" => true,
                    "length" => 131072,
                    "start"  => 4087349248
                  },
                  { "active" => true, "length" => 4096, "start" => 4087590912 }
                ]
              },
              "rev"            => "4",
              "slot_id"        => 25,
              "sub_class_id"   => 0,
              "sub_device_id"  => 74227,
              "sub_vendor"     => "Vendor",
              "sub_vendor_id"  => 7,
              "sysfs_bus_id"   => "0000:00:19.0",
              "sysfs_id"       => "/devices/pci0000:00/0000:00:19.0",
              "unique_key"     => "rBUF.41x4AT4gee2",
              "vendor"         => "Intel Corporation",
              "vendor_id"      => 98438
            }
          ]
        },
        "sysconfig" => { "console" => { "CONSOLE_ENCODING" => "UTF-8" } }
      }

      @EXEC = {
        "target" => {
          "bash_output" => {
            "exit"   => 0,
            "stdout" => "charset=UTF-8",
            "stderr" => ""
          }
        }
      }

      Testsuite.Init([@READ, {}, @EXEC], nil)

      Yast.import "NetworkInterfaces"
      Yast.import "LanItems"

      Testsuite.Test(LanItems.Read, [@READ, {}, @EXEC], nil)

      Testsuite.Dump("LanItems::GetNetcardNames")

      @expected_ifaces = ["bond0", "br0", "eth1", "eth11", "eth12", "eth2", "eth4", "eth5", "tap0", "tun0"]
      @ifaces = LanItems.GetNetcardNames
      @ifaces = Builtins.sort(@ifaces)

      Assert.Equal(@expected_ifaces, @ifaces)

      nil
    end
  end
end

Yast::BridgeClient.new.main