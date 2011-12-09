#!/usr/bin/perl
# This sample sets up two servers.  One of them accepts an input feed
# from its clients and broadcasts that input to the clients of the
# other.  For lack of a better name, I've called this a tcp bridge.
# This version supports multiple feeds and multiple data consumers.
# Every feed will broadcast to every consumer.
# A lot of people are confused by the array slice convention for event
# handler parameters.  The reasons for it are explained here:
# http://poe.perl.org/?POE_FAQ/Why_does_POE_pass_parameters_as_array_slices
# This sample requires POE version 0.1702 or higher.  Please see:
# http://poe.perl.org/?Where_to_Get_POE
# About the KERNEL, HEAP, and ARG0-style parameters:
# KERNEL is a reference to POE's main module, POE::Kernel.  It holds
# most of the low-level functions for posting events, watching files,
# setting timers, and so on.
# HEAP is a reference to a per-session storage space.  If you're
# familiar with threads, it is similar to thread-local storage.
# Because POE includes several runtime context parameters with every
# event, any parameters you include have been pushed to higher places
# in @_.  ARG0 is the offset of the first real parameter in @_, and
# ARG1..ARG9 are conveniences.  Because the real parameters are always
# at the end of @_, it's possible to retrieve them all at once with:
# my (@args) = @_[ARG0..$#_]
use warnings;
use strict;

# Use POE and also the TCP server component.
use POE qw(Component::Server::TCP);
sub FEED_SERVER_PORT ()     { 4489 }
sub CONSUMER_SERVER_PORT () { 4488 }

# A helper to log things.  You could also use POE::Component::Logger
# to direct logging to a file or syslog.
sub printlog {
  my $message_string = join("", @_);
  my $date_string = localtime();
  print "$date_string $message_string\n";
}

# A table of data consumers.  Input from clients attached to the feed
# server will be broadcast to every consumer listed in this table.
my %clients;
my %feed;
# The consumer server.  Every consumer connection will receive what
# was sent to each feed connection.
POE::Component::Server::TCP->new(
  Port => CONSUMER_SERVER_PORT,

  # A server error occurred.  Perform a graceless stop.
  Error => sub {
    my ($syscall, $error_number, $error_message) = @_[ARG0 .. ARG2];
    die("Couldn't start consumer server: ",
      "$syscall error $error_number: $error_message");
  },

  # Register new connections with the clients table, and log their
  # connections.
  ClientConnected => sub {
    my $client_id = $_[SESSION]->ID();
    $clients{$client_id} = "alive";
    printlog("Consuming connection $client_id started.");
    printlog("Feed server listening on port ",     FEED_SERVER_PORT);
    
    # The feed server.  Whatever is sent to this server will be broadcast
    # to every consumer.
    $feed{$client_id} = POE::Component::Server::TCP->new(
      Port => FEED_SERVER_PORT,
      # A server error occurred.  Perform a graceless stop.
      Error => sub {
        my ($syscall, $error_number, $error_message) = @_[ARG0 .. ARG2];
        die("Couldn't start feed server: ",
          "$syscall error $error_number: $error_message");
      },

      # Log that a client has connected to the feed server.
      ClientConnected => sub {
        my $client_id = $_[SESSION]->ID();
        printlog("Feed connection $client_id started.");
      },

      # Log that a client has disconnected from the feed server.
      ClientDisconnected => sub {
        my $client_id = $_[SESSION]->ID();
        printlog("Feed connection $client_id stopped.");
      },

      # Broadcast all feed input to any data consumers out there.  This
      # posts a message to each client session, requesting that it send
      # the input to its client socket.
      ClientInput => sub {
        my ($kernel, $input) = @_[KERNEL, ARG0];
        foreach my $client_id (keys %clients) {
          $kernel->post($client_id => send_message => $input);
        }
      },
    );
  },

  # Remove departing connections from the clients table, and log
  # their disconnections.
  ClientDisconnected => sub {
    my $heap = $_[HEAP];
    my $client_id = $_[SESSION]->ID();
    delete $feed{$client_id};
    delete $clients{$client_id};
    delete $heap->{feed};
    printlog("Consuming connection $client_id stopped.");
  },

  # Ignore client input.  Data consumers cannot talk back to their
  # feeds.
  ClientInput => sub {

    # Do nothing.
  },

  # Custom event handlers go here.  The "send_message" event
  # requests that we send something to the client.
  InlineStates => {
    send_message => sub {
      my ($heap, $message) = @_[HEAP, ARG0];
      $heap->{client}->put($message);
    },
  },
);

# Run the servers until something stops them.

printlog("Consumer server listening on port ", CONSUMER_SERVER_PORT);
$poe_kernel->run();
exit 0;
