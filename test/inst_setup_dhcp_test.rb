#!/usr/bin/env rspec

require_relative "test_helper"

require "network/clients/inst_setup_dhcp"

describe Yast::SetupDhcp do
  before(:all) do
    skip("Unusable bcs of LanItems::Items removal")
  end

  subject { Yast::SetupDhcp.instance }

  describe "#main" do

    it "returns :next when autoconfiguration is performed" do
      allow(Yast::NetworkAutoconfiguration)
        .to receive(:any_iface_active?)
        .and_return(true)

      expect(subject.main).to eql :next
    end

    it "returns :next when autoconfiguration is not performed" do
      allow(Yast::NetworkAutoconfiguration)
        .to receive(:any_iface_active?)
        .and_return(false)

      expect(subject.main).to eql :next
    end

    it "runs network dhcp autoconfiguration if no active interfaces" do
      allow(Yast::NetworkAutoconfiguration)
        .to receive(:any_iface_active?)
        .and_return(false)
      expect(Yast::NetworkAutoconfiguration.instance)
        .to receive(:configure_dhcp)

      subject.main
    end

    context "in the initial Stage" do
      it "writes DHCLIENT_SET_HOSTNAME in /etc/sysconfig/network/dhcp" do
        expect(Yast::Stage).to receive(:initial).and_return(true)
        expect(subject).to receive(:set_dhcp_hostname!)

        subject.main
      end
    end
  end

  describe "#set_dhcp_hostname!" do
    let(:dhclient_set_hostname_path) do
      Yast::Path.new(".sysconfig.network.dhcp.DHCLIENT_SET_HOSTNAME")
    end

    before do
      allow(Yast::SCR).to receive(:Write)
    end

    context "when the linurc sethostname option has been used" do
      before do
        allow(subject).to receive(:set_hostname_used?).and_return(true)
      end

      it "sets DNS.dhcp_hostname according to the linuxrc sethosname value" do
        expect(subject).to receive(:set_dhcp_hostname?).and_return(false)
        expect(Yast::DNS).to receive(:dhcp_hostname=).with(false)

        subject.set_dhcp_hostname!
      end
    end

    context "when the linurc sethostname option has not been used" do
      before do
        allow(subject).to receive(:set_hostname_used?).and_return(false)
      end

      it "sets DNS.dhcp_hostname according to DNS.default_dhcp_hostname" do
        expect(subject).to_not receive(:set_dhcp_hostname?)
        expect(Yast::DNS).to receive(:default_dhcp_hostname).and_return(true)
        expect(Yast::DNS).to receive(:dhcp_hostname=).with(true)

        subject.set_dhcp_hostname!
      end
    end

    context "once initialized DNS.dhcp_hostname" do
      it "writes global DHCLIENT_SET_HOSTNAME in /etc/sysconfig/network/dhcp with it" do
        allow(Yast::DNS).to receive(:dhcp_hostname=)
        allow(Yast::DNS).to receive(:dhcp_hostname).and_return(false)
        expect(Yast::SCR).to receive(:Write).with(dhclient_set_hostname_path, "no")

        subject.set_dhcp_hostname!
      end
    end
  end

  describe "set_dhcp_hostname?" do
    before do
      allow(Yast::Linuxrc).to receive(:InstallInf)
        .with("SetHostname").and_return(set_hostname)
    end

    context "when dhcp hostname has not been disabled by linuxrc" do
      let(:set_hostname) { "1" }

      it "returns true" do
        expect(subject.set_dhcp_hostname?).to eql(true)
      end
    end

    context "when dhcp hostname has been disabled by linuxrc" do
      let(:set_hostname) { "0" }

      it "returns false" do
        expect(subject.set_dhcp_hostname?).to eql(false)
      end
    end
  end
end
