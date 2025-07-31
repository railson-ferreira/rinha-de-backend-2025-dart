// https://www.pingorarust.com/quick_start

use std::env;
use std::net::ToSocketAddrs;
use async_trait::async_trait;
use pingora::lb::LoadBalancer;
use pingora::prelude::{HttpPeer, RoundRobin};
use pingora::proxy::{http_proxy_service, ProxyHttp, Session};
use pingora::server::Server;

pub struct LB(LoadBalancer<RoundRobin>, bool);
#[async_trait]
impl ProxyHttp for LB {
    /// For this small example, we don't need context storage
    type CTX = ();
    fn new_ctx(&self) -> () {
        ()
    }

    async fn upstream_peer(&self, _session: &mut Session, _ctx: &mut ()) -> Result<Box<HttpPeer>, Box<pingora::Error>> {
        _session.set_keepalive(None);
        let upstream = self.0
            .select(b"", 256) // hash doesn't matter for round robin
            .unwrap();

        if self.1 {
            println!("upstream peer is: {:?}", upstream);
        }

        let peer = Box::new(HttpPeer::new(upstream, false, "".to_string()));
        Ok(peer)
    }
}

fn validate_host(host: &str) -> Result<(), String> {
    let parts: Vec<&str> = host.rsplitn(2, ':').collect();
    if parts.len() != 2 {
        return Err(format!("Address '{}' does not contain a port", host));
    }

    let port_str = parts[0];
    let host_part = parts[1];

    if host_part.is_empty() {
        return Err(format!("Host part is empty in '{}'", host));
    }

    let port: u16 = port_str.parse().map_err(|_| {
        format!("Port '{}' in address '{}' is not a valid number", port_str, host)
    })?;

    if port == 0 {
        return Err(format!("Port cannot be zero in address '{}'", host));
    }

    Ok(())
}


fn main() {
    let upstream_hosts = env::var("HOSTS")
        .map_err(|_| "Environment variable HOSTS not set or unreadable").unwrap();

    println!("Upstream hosts: {}", upstream_hosts);
    let hosts: Result<Vec<_>, _> = upstream_hosts
        .split(',')
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        // Validate each host string as a SocketAddr
        .map(|host| {
            validate_host(host)?;
            host.to_socket_addrs()
                .map_err(|e| format!("DNS resolution failed for {}: {}", host, e))?
                .next()
                .ok_or_else(|| format!("No address found for {}", host))
        })
        .collect();
    println!("Resolved upstream hosts: {:?}", hosts);

    let hosts = hosts.unwrap(); // If any address is invalid, returns error here

    // Note that upstreams needs to be declared as `mut` now
    let upstreams =
        LoadBalancer::try_from_iter(hosts).unwrap();


    let mut my_server = Server::new(None).unwrap();

    // `upstreams` no longer need to be wrapped in an arc
    let debug = env::var("DEBUG").unwrap_or_else(|_| "false".to_string()) == "true";
    let mut lb = http_proxy_service(&my_server.configuration, LB(upstreams, debug));
    let port = env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let addr = format!("0.0.0.0:{}", port);
    lb.add_tcp(&addr);


    my_server.add_service(lb);
    println!("Pingora HTTP proxy started on {}", addr);
    my_server.run_forever();
}
