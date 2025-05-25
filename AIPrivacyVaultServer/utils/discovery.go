package utils

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/grandcat/zeroconf"
)

type DiscoveryService struct {
	server      *zeroconf.Server
	serviceName string
	port        string
	ctx         context.Context
	cancel      context.CancelFunc
}

func NewDiscoveryService(serviceName, port string) *DiscoveryService {
	startTime := time.Now()
	log.Printf("Creating discovery service for %s on port %s", serviceName, port)

	ctx, cancel := context.WithCancel(context.Background())

	ds := &DiscoveryService{
		serviceName: serviceName,
		port:        port,
		ctx:         ctx,
		cancel:      cancel,
	}

	log.Printf("Discovery service created in %v", time.Since(startTime))
	return ds
}

func (ds *DiscoveryService) Advertise() error {
	startTime := time.Now()
	log.Printf("Starting service advertisement...")

	hostnameTime := time.Now()
	hostname, err := os.Hostname()
	if err != nil {
		log.Printf("Warning: Failed to get hostname in %v: %v", time.Since(hostnameTime), err)
		hostname = "unknown"
	}
	log.Printf("Got hostname in %v: %s", time.Since(hostnameTime), hostname)

	instanceName := fmt.Sprintf("%s (%s)", ds.serviceName, hostname)

	var port int
	fmt.Sscanf(ds.port, "%d", &port)
	log.Printf("Using port: %d", port)

	regTime := time.Now()
	log.Printf("Registering mDNS service...")
	server, err := zeroconf.Register(
		instanceName,
		"_aiprivacyvault._tcp",
		"local.",
		port,
		[]string{"version=1.0"},
		nil,
	)

	if err != nil {
		log.Printf("Failed to register mDNS service in %v: %v", time.Since(regTime), err)
		return err
	}
	log.Printf("mDNS service registered in %v", time.Since(regTime))

	ds.server = server
	log.Printf("Service advertisement completed in %v", time.Since(startTime))
	return nil
}

func (ds *DiscoveryService) Browse() []ServiceInstance {
	startTime := time.Now()
	log.Printf("Browsing for services on the network...")

	instances := []ServiceInstance{}

	resolverTime := time.Now()
	log.Printf("Creating mDNS resolver...")
	resolver, err := zeroconf.NewResolver(nil)
	if err != nil {
		log.Printf("Failed to create resolver in %v: %v", time.Since(resolverTime), err)
		return instances
	}
	log.Printf("mDNS resolver created in %v", time.Since(resolverTime))

	log.Printf("Setting up browse timeout of 1 second")
	browseCtx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	entries := make(chan *zeroconf.ServiceEntry, 5)

	resultsCount := 0
	go func() {
		for entry := range entries {
			log.Printf("Found service: %s", entry.Instance)
			resultsCount++

			if len(entry.AddrIPv4) > 0 {
				instances = append(instances, ServiceInstance{
					Name:     entry.Instance,
					Address:  entry.AddrIPv4[0].String(),
					Port:     entry.Port,
					Hostname: entry.HostName,
				})
			} else {
				log.Printf("Service has no IPv4 address: %s", entry.Instance)
			}
		}
	}()

	browseTime := time.Now()
	log.Printf("Starting mDNS browse operation...")
	err = resolver.Browse(browseCtx, "_aiprivacyvault._tcp", "local.", entries)
	if err != nil {
		log.Printf("Failed to browse in %v: %v", time.Since(browseTime), err)
	}

	log.Printf("Waiting for browse timeout...")
	<-browseCtx.Done()
	log.Printf("Browse operation completed in %v, found %d services", time.Since(startTime), resultsCount)
	return instances
}

func (ds *DiscoveryService) Stop() {
	startTime := time.Now()
	log.Printf("Stopping discovery service...")

	if ds.server != nil {
		serverTime := time.Now()
		log.Printf("Shutting down mDNS server...")
		ds.server.Shutdown()
		ds.server = nil
		log.Printf("mDNS server shutdown in %v", time.Since(serverTime))
	}

	cancelTime := time.Now()
	log.Printf("Cancelling context...")
	ds.cancel()
	log.Printf("Context cancelled in %v", time.Since(cancelTime))

	log.Printf("Discovery service stopped in %v", time.Since(startTime))
}

func (ds *DiscoveryService) IsRunning() bool {
	return ds != nil && ds.server != nil
}

type ServiceInstance struct {
	Name     string
	Address  string
	Port     int
	Hostname string
}
