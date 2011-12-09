#!/usr/bin/perl -w
use IO::Socket;
my $socket = new IO::Socket::INET (
				PeerAddr => 'localhost',
				PeerPort => '4488',
				Proto => 'tcp',
				);
die "Could not create socket: $!\n" unless $socket;
#print "Connecting\n";
while (1)
{
	
    $socket->recv($recv_data,1024);
    
    print "$recv_data";        

    #$socket->send("$recv_data Ack\n");
}


