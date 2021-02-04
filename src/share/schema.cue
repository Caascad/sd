package discovery

//generic definitions
#UUID: =~"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"

//fields definitions
#ServiceDiscoveryUUID: S:       #UUID
#ServiceDiscoveryIP: S:         string
#ServiceDiscoveryObjectType: S: "loadbalancer" | "ip" | "zones"
#ServideDiscoveryZone: S:       string

#ServiceDiscoveryZones: M: {...} //whole caascad zones scheme could be included here besides it is not very useful
#ServiceDiscoveryProviderId: S:  string

//item definitions
Items: [ ...#ServiceDiscoveryItem]
#ServiceDiscoveryItem: {
	#ServiceDiscoveryBaseItem
	object_type: _
	if object_type.S == "ip" {
		#ServiceDiscoveryIPItem
	}
	if object_type.S == "loadbalancer" {
		#ServiceDiscoveryLoadBalancerItem
	}
	if object_type.S == "zones" {
		#ServiceDiscoveryZonesItem
	}
}

#ServiceDiscoveryBaseItem: {
	id:          #ServiceDiscoveryUUID
	object_type: #ServiceDiscoveryObjectType
	schema_version: S: string
	tags: L: [ ...#TagElement]
}

#TagElement: S: string

#ServiceDiscoveryIPItem: {
	ip:   #ServiceDiscoveryIP
	zone: #ServideDiscoveryZone
	uuid: #ServiceDiscoveryProviderId
}

#ServiceDiscoveryLoadBalancerItem: {
	zone: #ServideDiscoveryZone
	uuid: #ServiceDiscoveryProviderId
}

#ServiceDiscoveryZonesItem: {
	#ServiceDiscoveryItemzones: #ServiceDiscoveryZones
}

//AWS S3 bottom answer
Count?:            int
ScannedCount?:     int
ConsumedCapacity?: null | int
