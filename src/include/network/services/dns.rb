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
# File:	include/network/lan/dialogs.ycp
# Package:	Network configuration
# Summary:	Summary, overview and IO dialogs for network cards config
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkServicesDnsInclude

    CUSTOM_RESOLV_POLICIES = {
      "STATIC" =>          "STATIC",
      "STATIC_FALLBACK" => "STATIC_FALLBACK"
    }

    def initialize_network_services_dns(include_target)
      textdomain "network"

      Yast.import "CWM"
      Yast.import "DNS"
      Yast.import "GetInstArgs"
      Yast.import "Host"
      Yast.import "Hostname"
      Yast.import "IP"
      Yast.import "Label"
      Yast.import "Lan"
      Yast.import "NetworkConfig"
      Yast.import "Popup"
      Yast.import "Map"
      Yast.import "CWMTab"

      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/widgets.rb"
      Yast.include include_target, "network/lan/help.rb"

      # If we know that there are no interfaces with DHCP, we can disable
      # the check boxes.
      # Each dialog must set this variable.
      # HostnameDialog does not know yet whether we will have DHCP so it
      # assumes yes.
      # DNSMainDialog can query Lan::.
      @has_dhcp = true

      # If there's a process modifying resolv.conf, we warn the user before
      # letting him change things that will be overwritten anyway.
      # See also #61000.
      @resolver_modifiable = false

      # original setup, used to determine whether data have been modified
      @settings_orig = {}

      # CWM buffer for both dialogs.  Note that NAMESERVERS and SEARCHLIST
      # are lists and their widgets are suffixed.
      @hn_settings = {}

      @widget_descr_dns = {
        "HOSTNAME"        => {
          "widget"            => :textentry,
          # textentry label
          "label"             => Label.HostName,
          "opt"               => [],
          "help"              => Ops.get_string(@help, "hostname_global", ""),
          "valid_chars"       => Hostname.ValidChars,
          "validate_type"     => :function_no_popup,
          "validate_function" => fun_ref(
            method(:ValidateHostname),
            "boolean (string, map)"
          ),
          # validation error popup
          "validate_help"     => Ops.add(
            _("The hostname is invalid.") + "\n",
            Hostname.ValidHost
          )
        },
        "HOSTNAME_GLOBAL" => {
          "widget" => :empty,
          # #91202
          "init"   => fun_ref(
            method(:initHostnameGlobal),
            "void (string)"
          ),
          "store"  => fun_ref(
            method(:storeHostnameGlobal),
            "void (string, map)"
          )
        },
        "DOMAIN"          => {
          "widget"            => :textentry,
          # textentry label
          "label"             => _("&Domain Name"),
          "opt"               => [],
          # Do nothing (the widget doesnt have notify anyway)
          # In particular do not disable the host and domain name widgets,
          # setting of FQDN should be possible even if DHCP overrides it.
          # N#28427, N#63423.
          # "handle": nil,
          "valid_chars"       => Hostname.ValidCharsDomain(
          ),
          "validate_type"     => :function_no_popup,
          "validate_function" => fun_ref(
            method(:ValidateDomain),
            "boolean (string, map)"
          ),
          # validation error popup
          "validate_help"     => Ops.add(
            _("The domain name is invalid.") + "\n",
            Hostname.ValidDomain
          )
        },
        "DHCP_HOSTNAME"   => {
          "widget"        => :custom,
          "custom_widget" => HBox(
            CheckBox(Id("DHCP_HOSTNAME"), _("&Change Hostname via DHCP"), true),
            ReplacePoint(Id("dh_host_text"), Empty())
          ),
          # help
          "help"          => Ops.get_string(@help, "dhcp_hostname", ""),
          "init"          => fun_ref(method(:InitDhcpHostname), "void (string)")
        },
        "WRITE_HOSTNAME"  => {
          "widget" => :checkbox,
          # checkbox label
          "label"  => _("&Assign Hostname to Loopback IP"),
          "opt"    => [],
          # help
          "help"   => Ops.get_string(@help, "write_hostname", "")
        },
        "MODIFY_RESOLV"   => {
          "widget" => :combobox,
          "label"  => _("&Modify DNS configuration"),
          "opt"    => [:notify],
          "items"  => [
            [:nomodify, _("Only Manually")],
            [:auto, _("Use Default Policy")],
            [:custom, _("Use Custom Policy")]
          ],
          "init"   => fun_ref(method(:initModifyResolvPolicy), "void (string)"),
          "handle" => fun_ref(
            method(:handleModifyResolvPolicy),
            "symbol (string, map)"
          ),
          "help"   => Ops.get_string(@help, "dns_config_policy", "")
        },
        "PLAIN_POLICY"    => {
          "widget" => :combobox,
          "label"  => _("&Custom Policy Rule"),
          "opt"    => [:editable],
          "items"  => CUSTOM_RESOLV_POLICIES.to_a,
          "init"   => fun_ref(method(:initPolicy), "void (string)"),
          "handle" => fun_ref(method(:handlePolicy), "symbol (string, map)"),
          "help"   => ""
        },
        "NAMESERVER_1"    => {
          "widget"            => :textentry,
          # textentry label
          "label"             => _("Name Server &1"),
          "opt"               => [],
          "help"              => "",
          # at "SEARCHLIST_S"
          "handle"            => fun_ref(
            method(:HandleResolverData),
            "symbol (string, map)"
          ),
          "valid_chars"       => IP.ValidChars,
          "validate_type"     => :function_no_popup,
          "validate_function" => fun_ref(
            method(:ValidateIP),
            "boolean (string, map)"
          ),
          # validation error popup
          "validate_help"     => Ops.add(
            _("The IP address of the name server is invalid.") + "\n",
            IP.Valid4
          )
        },
        # NAMESERVER_2 and NAMESERVER_3 are cloned in the dialog function
        "SEARCHLIST_S"    => {
          "widget"            => :multi_line_edit,
          # textentry label
          "label"             => _("Do&main Search"),
          "opt"               => [],
          "help"              => Ops.get_string(@help, "searchlist_s", ""),
          "handle"            => fun_ref(
            method(:HandleResolverData),
            "symbol (string, map)"
          ),
          #	"valid_chars": Hostname::ValidCharsFQ, // TODO: whitespace. unused anyway?
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidateSearchList),
            "boolean (string, map)"
          )
        }
      }

      Ops.set(
        @widget_descr_dns,
        "NAMESERVER_2",
        Ops.get(@widget_descr_dns, "NAMESERVER_1", {})
      )
      Ops.set(
        @widget_descr_dns,
        "NAMESERVER_3",
        Ops.get(@widget_descr_dns, "NAMESERVER_1", {})
      )
      # text entry label
      Ops.set(@widget_descr_dns, ["NAMESERVER_2", "label"], _("Name Server &2"))
      # text entry label
      Ops.set(@widget_descr_dns, ["NAMESERVER_3", "label"], _("Name Server &3"))

      @dns_contents = VBox(
        Frame(
          _("Hostname and Domain Name"),
          VBox(
            HBox(
              "HOSTNAME",
              "HOSTNAME_GLOBAL", # global help, init, store for all dialog
              HSpacing(1),
              "DOMAIN"
            ),
            # CheckBox label
            Left("DHCP_HOSTNAME"),
            Left("WRITE_HOSTNAME")
          )
        ),
        VSpacing(0.49),
        Left(HBox("MODIFY_RESOLV", HSpacing(1), "PLAIN_POLICY")),
        # Frame label
        Frame(
          _("Name Servers and Domain Search List"),
          VBox(
            VSquash(
              HBox(
                HWeight(1, VBox("NAMESERVER_1", "NAMESERVER_2", "NAMESERVER_3")),
                HSpacing(1),
                HWeight(1, "SEARCHLIST_S")
              )
            ),
            VSpacing(0.49)
          )
        ),
        VStretch()
      )

      @dns_td = {
        "resolv" => {
          "header"       => _("Hostname/DNS"),
          "contents"     => @dns_contents,
          "widget_names" => [
            "HOSTNAME",
            "HOSTNAME_GLOBAL",
            "DOMAIN",
            "DHCP_HOSTNAME",
            "WRITE_HOSTNAME",
            "MODIFY_RESOLV",
            "PLAIN_POLICY",
            "NAMESERVER_1",
            "NAMESERVER_2",
            "NAMESERVER_3",
            "SEARCHLIST_S"
          ]
        }
      }
    end

    # @param [Array<String>] l list of strings
    # @return only non-empty items
    def NonEmpty(l)
      l = deep_copy(l)
      Builtins.filter(l) { |s| s != "" }
    end

    # @return initial settings for this dialog in one map, from DNS::
    def InitSettings
      settings = {
        "HOSTNAME"       => DNS.hostname,
        "DOMAIN"         => DNS.domain,
        "DHCP_HOSTNAME"  => DNS.dhcp_hostname,
        "WRITE_HOSTNAME" => DNS.write_hostname,
        "PLAIN_POLICY"   => DNS.resolv_conf_policy
      }
      # the rest is not so straightforward,
      # because we have list variables but non-list widgets

      # domain search
      searchstring = Builtins.mergestring(DNS.searchlist, "\n")
      # #49094: populate the search list
      # #437759: discard 'site', nobody really wants that pre-set
      if searchstring == "" && Ops.get_string(settings, "DOMAIN", "") != "site"
        searchstring = Ops.get_string(settings, "DOMAIN", "")
      end
      Ops.set(settings, "SEARCHLIST_S", searchstring)
      Ops.set(settings, "NAMESERVER_1", Ops.get(DNS.nameservers, 0, ""))
      Ops.set(settings, "NAMESERVER_2", Ops.get(DNS.nameservers, 1, ""))
      Ops.set(settings, "NAMESERVER_3", Ops.get(DNS.nameservers, 2, ""))

      @settings_orig = deep_copy(settings)

      deep_copy(settings)
    end

    # @param [Hash] settings map of settings to be stored to DNS::
    def StoreSettings(settings)
      settings = deep_copy(settings)
      nameservers = [
        Ops.get_string(settings, "NAMESERVER_1", ""),
        Ops.get_string(settings, "NAMESERVER_2", ""),
        Ops.get_string(settings, "NAMESERVER_3", "")
      ]
      searchlist = Builtins.splitstring(
        Ops.get_string(settings, "SEARCHLIST_S", ""),
        " ,\n\t"
      )

      DNS.hostname = Ops.get_string(settings, "HOSTNAME", "")
      DNS.domain = Ops.get_string(settings, "DOMAIN", "")
      DNS.nameservers = NonEmpty(nameservers)
      DNS.searchlist = NonEmpty(searchlist)
      DNS.dhcp_hostname = Ops.get_boolean(settings, "DHCP_HOSTNAME", false)
      DNS.write_hostname = Ops.get_boolean(settings, "WRITE_HOSTNAME", true)

      # "auto" is default defined in netconfig
      policy_name = CUSTOM_RESOLV_POLICIES[settings["PLAIN_POLICY"]]
      DNS.resolv_conf_policy = policy_name

      # update modified flag
      DNS.modified = DNS.modified || settings != @settings_orig
      Builtins.y2milestone("Modified DNS: %1", DNS.modified)

      nil
    end

    # Stores actual hostname settings.
    def StoreHnSettings
      StoreSettings(@hn_settings)

      nil
    end

    # Initialize internal state according current system configuration.
    def InitHnSettings
      @has_dhcp = Lan.AnyDHCPDevice

      @hn_settings = InitSettings()

      nil
    end

    # Function for updating actual hostname settings.
    # @param [String] key for known keys see hn_settings
    # @param [Object] value value for particular hn_settings key
    def SetHnItem(key, value)
      value = deep_copy(value)
      Builtins.y2milestone(
        "hn_settings[ \"%1\"] changes '%2' -> '%3'",
        key,
        Ops.get_string(@hn_settings, key, ""),
        value
      )
      Ops.set(@hn_settings, key, value)

      nil
    end

    # Function for updating actual hostname.
    def SetHostname(value)
      value = deep_copy(value)
      SetHnItem("HOSTNAME", value)

      nil
    end

    # Function for updating ip address of first nameserver.
    def SetNameserver1(value)
      value = deep_copy(value)
      SetHnItem("NAMESERVER_1", value)

      nil
    end

    # Function for updating ip address of second nameserver.
    def SetNameserver2(value)
      value = deep_copy(value)
      SetHnItem("NAMESERVER_2", value)

      nil
    end

    # Function for updating ip address of third nameserver.
    def SetNameserver3(value)
      value = deep_copy(value)
      SetHnItem("NAMESERVER_3", value)

      nil
    end

    # Default function to init the value of a widget.
    # Used for push buttons.
    # @param [String] key id of the widget
    def InitHnWidget(key)
      value = Ops.get(@hn_settings, key)
      UI.ChangeWidget(Id(key), :Value, value)

      nil
    end


    # Default function to store the value of a widget.
    # @param [String] key	id of the widget
    # @param [Hash] event	the event being handled
    def StoreHnWidget(key, event)
      event = deep_copy(event)
      value = UI.QueryWidget(Id(key), :Value)
      SetHnItem(key, value)

      nil
    end

    # Init handler for DHCP_HOSTNAME.
    # enable or disable: is DHCP available?
    # @param [String] key	the widget receiving the event
    # @param event	the event being handled
    # @return nil so that the dialog loops on
    def InitDhcpHostname(key)
      UI.ChangeWidget(Id("DHCP_HOSTNAME"), :Enabled, @has_dhcp)
      if !@has_dhcp
        UI.ReplaceWidget(Id("dh_host_text"), Label(_("No interface with dhcp")))
      else
        # the hostname dialog proposes to update it by DHCP on a laptop (#326102)
        UI.ChangeWidget(
          Id("DHCP_HOSTNAME"),
          :Value,
          Ops.get_boolean(@hn_settings, "DHCP_HOSTNAME", true)
        )
      end
      nil
    end

    # Event handler for resolver data (nameservers, searchlist)
    # enable or disable: is DHCP available?
    # @param [String] key	the widget receiving the event
    # @param [Hash] event	the event being handled
    # @return nil so that the dialog loops on
    def HandleResolverData(key, event)
      event = deep_copy(event)
      #if this one is disabled, it means NM is in charge (see also initModifyResolvPolicy())
      if Convert.to_boolean(UI.QueryWidget(Id("MODIFY_RESOLV"), :Enabled))
        #thus, we should not re-enable already disabled widgets
        UI.ChangeWidget(Id(key), :Enabled, @resolver_modifiable)
      end
      nil
    end

    # Validator for hostname, no_popup
    # @param [String] key	the widget being validated
    # @param [Hash] event	the event being handled
    # @return whether valid
    def ValidateHostname(key, event)
      event = deep_copy(event)
      dhn = @has_dhcp &&
        Convert.to_boolean(UI.QueryWidget(Id("DHCP_HOSTNAME"), :Value))
      # If the names are set by dhcp, the user may enter backup values
      # here - N#28427. That is, host and domain name are optional then.
      # For static config, they are mandatory.
      value = Convert.to_string(UI.QueryWidget(Id(key), :Value))

      return Hostname.Check(value) if !dhn || value != ""
      true
    end

    # Validator for domain name, no_popup
    # @param [String] key	the widget being validated
    # @param [Hash] event	the event being handled
    # @return whether valid
    def ValidateDomain(key, event)
      event = deep_copy(event)
      dhn = @has_dhcp &&
        Convert.to_boolean(UI.QueryWidget(Id("DHCP_HOSTNAME"), :Value))
      value = Convert.to_string(UI.QueryWidget(Id(key), :Value))

      if !dhn || value != ""
        if value == "local"
          if !Popup.YesNo(
              _(
                "It's not recommended to use .local as domainname due to Multicast DNS. Use it at your own risk?"
              )
            )
            return false
          end
        end
        return Hostname.CheckDomain(value)
      end
      true
    end

    # Validator for the search list
    # @param [String] key	the widget being validated
    # @param [Hash] event	the event being handled
    # @return whether valid
    def ValidateSearchList(key, event)
      event = deep_copy(event)
      value = Convert.to_string(UI.QueryWidget(Id(key), :Value))
      sl = NonEmpty(Builtins.splitstring(value, " ,\n\t"))
      error = ""

      if Ops.greater_than(Builtins.size(sl), 6)
        # Popup::Error text
        error = Builtins.sformat(
          _("The search list can have at most %1 domains."),
          6
        )
      elsif Ops.greater_than(Builtins.size(Builtins.mergestring(sl, " ")), 256)
        # Popup::Error text
        error = Builtins.sformat(
          _("The search list can have at most %1 characters."),
          256
        )
      end
      bad = Builtins.find(sl) do |s|
        if !Hostname.CheckDomain(s)
          # Popup::Error text
          error = Ops.add(
            Ops.add(
              Builtins.sformat(_("The search domain '%1' is invalid."), s),
              "\n"
            ),
            Hostname.ValidDomain
          )
          next true
        end
        false
      end

      if error != ""
        UI.SetFocus(Id(key))
        Popup.Error(error)
        return false
      end
      true
    end

    def initPolicy(key)
      #first initialize correctly
      Builtins.y2milestone(
        "initPolicy: %1",
        UI.QueryWidget(Id("MODIFY_RESOLV"), :Value)
      )
      if UI.QueryWidget(Id("MODIFY_RESOLV"), :Value) == :custom
        UI.ChangeWidget(Id("PLAIN_POLICY"), :Enabled, true)
        if UI.QueryWidget(Id("PLAIN_POLICY"), :Value) == ""
          UI.ChangeWidget(Id("PLAIN_POLICY"), :Value, DNS.resolv_conf_policy)
        end
      else
        UI.ChangeWidget(Id("PLAIN_POLICY"), :Value, "")
        UI.ChangeWidget(Id("PLAIN_POLICY"), :Enabled, false)
      end
      #then disable if needed
      disableItemsIfNM(["PLAIN_POLICY"], false)

      nil
    end

    def handlePolicy(key, event)
      event = deep_copy(event)
      Builtins.y2milestone("handlePolicy")

      case UI.QueryWidget(Id("MODIFY_RESOLV"), :Value)
        when :custom
          SetHnItem("PLAIN_POLICY", UI.QueryWidget(Id("PLAIN_POLICY"), :Value))
        when :auto
          SetHnItem("PLAIN_POLICY", :auto)
        else
          SetHnItem("PLAIN_POLICY", nil)
      end

      nil
    end

    def modify_resolv_default
      if DNS.resolv_conf_policy == nil || DNS.resolv_conf_policy == ""
        default = Id(:nomodify)
      elsif DNS.resolv_conf_policy == "auto" || DNS.resolv_conf_policy == "STATIC *"
        default = Id(:auto)
      else
        default = Id(:custom)
      end
    end

    def initModifyResolvPolicy(key)
      Builtins.y2milestone("initModifyResolvPolicy")

      #first initialize correctly
      default = modify_resolv_default

      UI.ChangeWidget(Id("MODIFY_RESOLV"), :Value, default)
      #then disable if needed
      disableItemsIfNM(["MODIFY_RESOLV"], false)

      nil
    end

    def handleModifyResolvPolicy(key, event)
      event = deep_copy(event)
      Builtins.y2milestone(
        "handleModifyResolvPolicy called: %1",
        UI.QueryWidget(Id("MODIFY_RESOLV"), :Value)
      )

      if UI.QueryWidget(Id("MODIFY_RESOLV"), :Value) == :nomodify
        @resolver_modifiable = false
      else
        @resolver_modifiable = true
      end

      initPolicy(key)

      Builtins.y2milestone(
        "Exit: resolver_modifiable = %1",
        @resolver_modifiable
      )
      nil
    end

    # Used in GUI mode - initializes widgets according hn_settings
    # @param [String] key ignored
    def initHostnameGlobal(key)
      InitHnSettings()

      Builtins.foreach(
        Convert.convert(
          Map.Keys(@hn_settings),
          :from => "list",
          :to   => "list <string>"
        )
      ) { |key2| InitHnWidget(key2) }
      #disable those if NM is in charge
      disableItemsIfNM(
        ["NAMESERVER_1", "NAMESERVER_2", "NAMESERVER_3", "SEARCHLIST_S"],
        false
      )

      nil
    end

    # Used in GUI mode - updates and stores actuall hostname settings according dialog widgets content.
    # It calls store handler for every widget from hn_settings with event as an option.
    # @param [String] key ignored
    # @param [Hash] event user generated event
    def storeHostnameGlobal(key, event)
      event = deep_copy(event)
      Builtins.foreach(
        Convert.convert(
          Map.Keys(@hn_settings),
          :from => "list",
          :to   => "list <string>"
        )
      ) { |key2| StoreHnWidget(key2, event) }

      StoreHnSettings()

      nil
    end

    def ReallyAbortInst
      Popup.ConfirmAbort(:incomplete)
    end

    def HostnameDialog
      @has_dhcp = true

      @hn_settings = InitSettings()

      functions = {
        "init"  => fun_ref(method(:InitHnWidget), "void (string)"),
        "store" => fun_ref(method(:StoreHnWidget), "void (string, map)"),
        :abort  => fun_ref(method(:ReallyAbortInst), "boolean ()")
      }
      contents = HSquash(
        # Frame label
        Frame(
          _("Hostname and Domain Name"),
          VBox(
            HBox("HOSTNAME", HSpacing(1), "DOMAIN"),
            Left("DHCP_HOSTNAME"),
            Left("WRITE_HOSTNAME")
          )
        )
      )

      ret = CWM.ShowAndRun(
        {
          "widget_descr"       => @widget_descr_dns,
          "contents"           => contents,
          # dialog caption
          "caption"            => _("Hostname and Domain Name"),
          "back_button"        => Label.BackButton,
          "next_button"        => Label.NextButton,
          "fallback_functions" => functions,
          "disable_buttons"    => GetInstArgs.enable_back ? [] : ["back_button"]
        }
      )

      if ret == :next
        #Pre-populate resolv.conf search list with current domain name
        #but only if none exists so far
        current_domain = Ops.get_string(@hn_settings, "DOMAIN", "")

        #Need to modify hn_settings explicitly as SEARCHLIST_S widget
        #does not exist in this dialog, thus StoreHnWidget won't do it
        ##438167
        if DNS.searchlist == [] && current_domain != "site"
          Ops.set(@hn_settings, "SEARCHLIST_S", current_domain)
        end

        StoreSettings(@hn_settings)
      end

      ret
    end

    # Standalone dialog only - embedded one is handled separately
    # via CWMTab
    def DNSMainDialog(standalone)
      caption = _("Hostname and Name Server Configuration")

      functions = {
        "init"  => fun_ref(method(:InitHnWidget), "void (string)"),
        "store" => fun_ref(method(:StoreHnWidget), "void (string, map)"),
        :abort  => fun_ref(method(:ReallyAbort), "boolean ()")
      }

      Wizard.HideBackButton

      ret = CWM.ShowAndRun(
        {
          "widget_descr"       => @widget_descr_dns,
          "contents"           => @dns_contents,
          # dialog caption
          "caption"            => caption,
          "back_button"        => Label.BackButton,
          "next_button"        => Label.FinishButton,
          "fallback_functions" => functions
        }
      )


      ret
    end
  end
end
