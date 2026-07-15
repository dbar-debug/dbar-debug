# WinboxMobile push stats v6
# RouterOS 6.39+/7.0+ required. 

:global wmUrlEncode do={
  :local Chars {" "="%20";"!"="%21";"\""="%22";"#"="%23";"$"="%24";"%"="%25";"&"="%26";"'"="%27";"("="%28";")"="%29";"*"="%2A";"+"="%2B";","="%2C";"-"="%2D";"."="%2E";"/"="%2F";":"="%3A";";"="%3B";"<"="%3C";"="="%3D";">"="%3E";"?"="%3F";"@"="%40";"["="%5B";"\\"="%5C";"]"="%5D";"^"="%5E";"`"="%60";"{"="%7B";"|"="%7C";"}"="%7D";"~"="%7E"}
  :local URLEncodeStr
  :local Char
  :local EncChar
  :for i from=0 to=([:len $1]-1) do={
    :set Char [:pick $1 $i]
    :set EncChar ($Chars->$Char)
    :if (any $EncChar) do={
      :set URLEncodeStr ($URLEncodeStr . $EncChar)
    } else={
      :set URLEncodeStr ($URLEncodeStr . $Char)
    }
  }
  :return $URLEncodeStr
}

:global wmInterfaceMonit do={
  :global wmUrlEncode;

  :local data; :local item; :local encodedName; :local linkDown; :local linkDownTime;
  :foreach i in=[/interface find type=$1 disabled=no] do={
    :set linkDown [/interface get $i link-downs];
    :set linkDownTime [$wmUrlEncode [/interface get $i last-link-down-time]];

    /interface monitor-traffic $i once do={
      :set encodedName [$wmUrlEncode $name];
      :set item "traffic[]=$1||$i||$encodedName||$"tx-bits-per-second"||$"rx-bits-per-second"||$"tx-packets-per-second"||$"rx-packets-per-second"||$linkDown||$linkDownTime"
      :set data ( $data . "&" . $item);
    }
  }
  :return $data
}

:local packageRouting true
:local packagePpp true
:local packageSecurity true
:local packageDhcp true
:local packageWireless true
:local packageHotspot true
:local majarVersion [:pick [/system resource get version] 0 1]
:if ($majarVersion = "6") do={
  :if ([/system package find name=routing disabled=no] = "") do={
    :set packageRouting false
  }
  :if ([/system package find name=ppp disabled=no] = "") do={
    :set packagePpp false
  }
  :if ([/system package find name=security disabled=no] = "") do={
    :set packageSecurity false
  }
  :if ([/system package find name=dhcp disabled=no] = "") do={
    :set packageDhcp false
  }
  :if ([/system package find name=wireless disabled=no] = "") do={
    :set packageWireless false
  }
  :if ([/system package find name=hotspot disabled=no] = "") do={
    :set packageHotspot false
  }
}

:local dataParams;
:set dataParams "push_stats_version=6&did=E322BDE0-4891-4C14-B75F-5F4AE5EA75B4&pid=";

:put "Collecting Board data..."
:do {
  :local serialNumber [/system routerboard get serial-number];
  :set dataParams   ( $dataParams . "&" . "serial_number=$serialNumber");
} on-error={ :put "Collecting Board data 1 error"};
:do {
  :local systemId     [/system license get system-id];
  :set dataParams   ( $dataParams . "&" . "system_id=$systemId");
} on-error={ :put "Collecting Board data 2 error"};
:do {
  :local softwareId   [/system license get software-id];
  :set dataParams   ( $dataParams . "&" . "software_id=$softwareId");
} on-error={ :put "Collecting Board data 3 error"};

:put "Collecting Performance data..."
:do {
  :local cpuLoad    [/system resource get cpu-load];
  :local memFree    [/system resource get free-memory];
  :local memTotal   [/system resource get total-memory];
  :local hddFree    [/system resource get free-hdd-space];
  :local hddTotal   [/system resource get total-hdd-space];
  :local userActive [/user active print count-only];
  :local perfData   "cpu_load=$cpuLoad&mem_free=$memFree&mem_total=$memTotal&hdd_free=$hddFree&hdd_total=$hddTotal&user_active_count=$userActive"
  :set dataParams ( $dataParams . "&" . $perfData);
} on-error={ :put "Collecting Performance error"};

:put "Collecting Health data..."
:do {
  :local encodedHealth [$wmUrlEncode [:tostr [/system health print as-value]]];
  :local healthData "health=$encodedHealth";
  :set dataParams ( $dataParams . "&" . $healthData);
} on-error={ :put "Collecting Health error"};

:put "Collecting Bridge data..."
:local bridgeData; :local bridgeHostCount; :local bridgeDataItem;
:do {
  :set bridgeHostCount  [/interface bridge host print count-only];
  :set bridgeData       "bridge_host[][bridge]=ALL&bridge_host[][count]=$bridgeHostCount"

  :set dataParams       ($dataParams . "&" . $bridgeData);
} on-error={ :put "Collecting Bridge error"};

:put "Collecting IP data..."
:local routerData; :local ipRouteCount; :local ipARPCount; :local ipPoolUsedCount; :local ipFwCount;
:do {
  :set ipRouteCount     [/ip route print count-only];
  :set ipARPCount       [/ip arp print count-only];
  :set ipPoolUsedCount  [/ip pool used print count-only];
  :set ipFwCount        [/ip firewall connection print count-only];
  :set routerData       "ip_route_count=$ipRouteCount&ip_arp_count=$ipARPCount&ip_pool_used_count=$ipPoolUsedCount&firewall_connection_count=$ipFwCount"
  :set dataParams     ($dataParams . "&" . $routerData);
} on-error={ :put "Collecting IP error"};

:if ($packageRouting = false) do={
  :put "routing package is not installed."
} else={
  :put "Collecting Routing data..."
  :local routingData; :local bgpPeerCount; :local ospfNeighborCount;
  :do {
    :set bgpPeerCount       [/routing bgp peer print count-only];
    :set ospfNeighborCount  [/routing ospf neighbor print count-only];
    :set routingData        "bgp_peer_count=$bgpPeerCount&ospf_neighbor_count=$ospfNeighborCount"
    :set dataParams         ($dataParams . "&" . $routingData);
  } on-error={ :put "Collecting Routing error"};
}

:put "Collecting VPN data...";
:local vpnData; :local vpnPppCount; :local vpnIpsecPeerCount; :local vpnIpsecPolicyCount;
:do {
  :if ($packagePpp = false) do={
    :set vpnPppCount            0;
  } else={
    :set vpnPppCount            [/ppp active print count-only];
  }

  :if ($packageSecurity = false) do={
    :set vpnIpsecPeerCount      0;
    :set vpnIpsecPolicyCount    0;
  } else={
    :set vpnIpsecPeerCount      [/ip ipsec active-peers print count-only];
    :set vpnIpsecPolicyCount    [/ip ipsec policy print count-only];
  }

  :set vpnData                "ppp_active_count=$vpnPppCount&ipsec_remote_peer_count=$vpnIpsecPeerCount&ipsec_policy_count=$vpnIpsecPolicyCount";
  :set dataParams ( $dataParams . "&" . $vpnData);
} on-error={ :put "Collecting VPN error"};

:if ($packageDhcp = false) do={
  :put "dhcp package is not installed."
} else={
  :put "Collecting DHCP data...";
  :local dhcpData;
  :do {
    :local leaseCount   [/ip dhcp-server lease print count-only];
    :set dhcpData       "dhcp_server_lease[][server]=ALL&dhcp_server_lease[][count]=$leaseCount";

    :set dataParams ( $dataParams . "&" . $dhcpData);
  } on-error={ :put "Collecting DHCP error"};
}

:if ($packageWireless = false) do={
  :put "wireless package is not installed."
} else={
  :put "Collecting Wireless data...";
  :local wirelessData; :local wirelessDataItem;
  :do {
    :local wirelessCount    [/interface wireless registration-table print count-only];
    :set wirelessData       "wireless_registration[][interface]=ALL&wireless_registration[][count]=$wirelessCount";

    :set dataParams ( $dataParams . "&" . $wirelessData);
  } on-error={ :put "Collecting Wireless error"};

  :put "Collecting CAPsMan data...";
  :local capsmanData; :local capsmanDataItem;
  :do {
    :local capsmanCAPCount      [/caps-man remote-cap print count-only];
    :local capsmanRegisCount    [/caps-man registration-table print count-only];
    :local capsmanRadioCount    [/caps-man radio print count-only];
    :set capsmanData            "capsman_remote_cap_count=$capsmanCAPCount&capsman_registration[][interface]=ALL&capsman_registration[][count]=$capsmanRegisCount&capsman_radio[][interface]=ALL&capsman_radio[][count]=$capsmanRadioCount";

    :set dataParams ( $dataParams . "&" . $capsmanData);
  } on-error={ :put "Collecting CAPsMan error"};
}

:if ($packageHotspot = false) do={
  :put "hotspot package is not installed."
} else={
  :put "Collecting Hotspot data...";
  :local hotspotData; :local hotspotDataItem;
  :do {
    :local cookieCount        [/ip hotspot cookie print count-only]
    :local activeCount        [/ip hotspot active print count-only]
    :local hostCount          [/ip hotspot host print count-only]
    :set hotspotData          "hotspot_cookie_count=$cookieCount&hotspot_active[][server]=ALL&hotspot_active[][count]=$activeCount&hotspot_host[][server]=ALL&hotspot_host[][count]=$hostCount";

    :set dataParams ( $dataParams . "&" . $hotspotData);
  } on-error={ :put "Collecting Hotspot error"};
}

:put "Collecting Interface data...";
:do {
  /interface monitor-traffic aggregate once do={
    :local aggregateData "traffic[]=aggregate||0||aggregate||$"tx-bits-per-second"||$"rx-bits-per-second"||$"tx-packets-per-second"||$"rx-packets-per-second""
    :set dataParams ( $dataParams . "&" . $aggregateData);
  }

  :set dataParams ( $dataParams . "&" . [$wmInterfaceMonit "ether"]);
  :set dataParams ( $dataParams . "&" . [$wmInterfaceMonit "wlan"]);
  :set dataParams ( $dataParams . "&" . [$wmInterfaceMonit "cap"]);
} on-error={ :put "Collecting Interface error"};

:do {
  :local identity   [$wmUrlEncode [/system identity get name]];
  :set dataParams ( $dataParams . "&" . "identity=$identity");
} on-error={ :put "Collecting identity error"};

:do {
  :local model      [$wmUrlEncode [/system routerboard get model]];
  :set dataParams ( $dataParams . "&" . "model=$model");
} on-error={ :put "Collecting model error"};

:do {
  :local version    [$wmUrlEncode [/system resource get version]];
  :set dataParams ( $dataParams . "&" . "version=$version");
} on-error={ :put "Collecting version error"};

:do {
  :local uptime     [$wmUrlEncode [/system resource get uptime]];
  :set dataParams ( $dataParams . "&" . "uptime=$uptime");
} on-error={ :put "Collecting uptime error"};

:put $dataParams;

:local finalURL "https://septudio.com/mik_push_stats"
/tool fetch url="$finalURL" http-method=post http-data="$dataParams" mode=https keep-result=no
