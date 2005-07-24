#!/usr/bin/perl
use strict;
use warnings;

# Once you want to do more than only a simple action within
# the signal handler it is usually better (more readable)
# to create a real function and when defining the signal handler
# privide a reference to this subroutin instead of the anonymous sub.
# In our case \&handle_exit_button is a reference to the handle_exit_button
# function that in turn is defined lower in the file.
# This function will print a small message on the consol before exiting the application.

use Gtk2 '-init';

my $window = Gtk2::Window->new;
$window->signal_connect (destroy => sub { Gtk2->main_quit; });

my $button = Gtk2::Button->new("Hello world!");
$button->signal_connect(clicked=> \&handle_exit_button);
$window->add($button);

$window->show_all();
Gtk2->main;

sub handle_exit_button {
	print "Exiting...\n";
	Gtk2->main_quit;
}