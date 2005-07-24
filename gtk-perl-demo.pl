#!/usr/bin/perl -w
use strict;
use warnings;
 
use Glib qw/TRUE FALSE/;
use Gtk2 '-init';
use Data::Dumper;
use File::Temp qw(tempfile);

our $VERSION = '0.01';
my ($ENTRY_NAME, $ENTRY_TYPE, $ENTRY_FILE) = (0, 1, 2);

my @entries = do "entries.pl"; 
if (@ARGV and $ARGV[0] eq "check") {
	check_files(\@entries);
	print "All the files are readable\n";
	exit;
}

my %files;
my %widgets;
my $current_list;
collect_widgets(\@entries);
 

my $window = Gtk2::Window->new;
$window->set_title("GTK+ Perl binding Tutorial and code demos");
$window->signal_connect (destroy => sub { Gtk2->main_quit; });
$window->set_default_size(800, 500);

my $vbox = Gtk2::VBox->new();
$window->add($vbox);

my $buttons = Gtk2::HBox->new();
$vbox->pack_start($buttons, FALSE, FALSE, 5);

my $toggle_button = Gtk2::Button->new("List Widgets");
$toggle_button->signal_connect(clicked=> \&toggle_list);
$buttons->pack_start($toggle_button, FALSE, FALSE, 5);

my $execute_button = Gtk2::Button->new("Execute");
$execute_button->signal_connect(clicked=> \&execute_code);
$buttons->pack_start($execute_button, FALSE, FALSE, 5);

my $save_button = Gtk2::Button->new("Save");
$save_button->signal_connect(clicked=> \&save_code);
$buttons->pack_start($save_button, FALSE, FALSE, 5);

my $search_entry = Gtk2::Entry->new;
$search_entry->set_activates_default (1);
$buttons->pack_start($search_entry, FALSE, FALSE, 5);

my $search_button = Gtk2::Button->new("Search");
$search_button->signal_connect(clicked=> \&search);
$buttons->pack_start($search_button, FALSE, FALSE, 5);

my $exit_button = Gtk2::Button->new("Exit");
$exit_button->signal_connect(clicked=> sub { Gtk2->main_quit; });
$buttons->pack_end($exit_button, FALSE, FALSE, 5);


my $hbox = Gtk2::HBox->new();
$vbox->pack_start($hbox, TRUE, TRUE, 5);

my $tree_store = Gtk2::TreeStore->new('Glib::String', 'Glib::String', 'Glib::String');
my $tree_view  = Gtk2::TreeView->new($tree_store);
$tree_view->signal_connect (button_release_event => \&button_release);
my $col = Gtk2::TreeViewColumn->new_with_attributes("Right click for demo", Gtk2::CellRendererText->new(), text => "0");
$tree_view->append_column($col);
$tree_view->set_headers_visible(0);

my $left_scroll = Gtk2::ScrolledWindow->new;
$left_scroll->set_policy ('never', 'automatic');
$left_scroll->add($tree_view);

$hbox->pack_start($left_scroll, FALSE, FALSE, 5);

list_examples();
my $buffer = Gtk2::TextBuffer->new();
show_file($buffer, "welcome.txt");

my $textview = Gtk2::TextView->new_with_buffer($buffer);
$textview->set_wrap_mode("word");

my $right_scroll = Gtk2::ScrolledWindow->new;
$right_scroll->set_policy ('never', 'automatic');
$right_scroll->add($textview);

$hbox->add($right_scroll);

$window->show_all();
Gtk2->main;

############################### END ################################

sub save_code {
	my $file_chooser = Gtk2::FileChooserDialog->new ('Save code',
				undef, 'save',
				'gtk-cancel' => 'cancel',
				'gtk-ok'     => 'ok');

	if ('ok' eq $file_chooser->run) {
		my $filename = $file_chooser->get_filename;
		if (-e $filename) {
			#print "filename $filename already exists\n";
		}
		if (open my $fh, ">", $filename) {
			print $fh $buffer->get_text($buffer->get_start_iter, $buffer->get_end_iter, 0);
		}
	}
	$file_chooser->destroy;
}

sub execute_code {
	if ($current_list eq "examples") {
		my ($name, $type, $file) = _translate_tree_selection();
		return if $type ne "file";
	} else {
		my ($path, $col) = $tree_view->get_cursor(); 
		my @c = split /:/, $path->to_string;
		return if @c != 2;
	}

	my ($fh, $temp_filename) = tempfile();
	print $fh $buffer->get_text($buffer->get_start_iter, $buffer->get_end_iter, 0);
	close $fh;
	system($^X, $temp_filename);
	unlink $temp_filename;
	return;
}


sub add_entries {
	my ($tree, $parent, $entries) = @_;
	foreach my $entry (@$entries) {
		my $child = $tree_store->append($parent);
		$tree->set($child, 
			$ENTRY_NAME => $entry->{title}, 
			$ENTRY_TYPE => $entry->{type}, 
			$ENTRY_FILE => $entry->{name});
		if ($entry->{more}) {
			add_entries($tree, $child, $entry->{more});
		}
	}
}

sub list_examples {
	$tree_store->clear();
	$current_list = "examples";
	add_entries($tree_store, undef, \@entries);
}

sub list_widgets {
	$tree_store->clear();
	$current_list = "widgets";
	foreach my $widget (sort keys %widgets) {
		my $child = $tree_store->append(undef);
		$tree_store->set($child, 0, $widget);
		foreach my $file (sort keys %{$widgets{$widget}}) {
			my $grandchild = $tree_store->append($child);
			$tree_store->set($grandchild, 0, $file);
		}
	}
}
	
sub toggle_list {
	my ($widget) = @_;
	my $label = $widget->get_label;
	if ($label eq "List Widgets") {
		list_widgets();
		$widget->set_label("List Examples");
	} else {
		list_examples();
		$widget->set_label("List Widgets");
	}
}

sub _translate_tree_selection {
	my $model     = $tree_view->get_model();
	my $selection = $tree_view->get_selection();
	my $iter      = $selection->get_selected();
	return if not defined $iter;
	return $model->get($iter, $ENTRY_NAME, $ENTRY_TYPE, $ENTRY_FILE);
}

sub button_release {
	my ($self, $event) = @_;
	if ($current_list eq "examples") {
		select_example();
	} else { #"widgets"
		select_widget();
	}
	return;
}
sub select_widget {
	my ($path, $col) = $tree_view->get_cursor(); 
	my @c = split /:/, $path->to_string;
	if (@c == 1) {
		show_text($buffer, "Please select one of the files");	
	} elsif (@c == 2) {
		my $widget = (sort keys %widgets)[$c[0]];
	 	my $filename = (sort keys %{$widgets{$widget}})[$c[1]];
		show_file($buffer, $filename);
	} else {
		show_text($buffer, "Internal error, bad tree item: " . $path->to_string);
	}
}

sub select_example {
	my ($name, $type, $file) = _translate_tree_selection();
	return if not $name; # maybe some error message ?

	show_file($buffer, $file);
	return;
}

sub show_file {
	my ($buffer, $filename) = @_;
	my $code;
	if (open my $fh, $filename) {
		$code = join "", <$fh>;
		close $fh;
	} else {
		$code = "ERROR: Could not open $filename; $!";
	}
	show_text($buffer, $code);
}

sub show_text {
	my ($buffer, $text) = @_;
	$buffer->delete($buffer->get_start_iter, $buffer->get_end_iter);
	$buffer->insert($buffer->get_iter_at_line(0), $text);
}


sub collect_widgets {
	my ($entries) = @_;

	foreach my $entry (@$entries) {
		if ($entry->{type} eq "file") {
			analyze_file($entry->{name});
		}
		collect_widgets($entry->{more}) if $entry->{more};
	}
	return;
}

sub analyze_file {
	my ($file) = @_;
	open my $fh, $file or return;
	while (my $line = <$fh>) {
		if ($line =~ /(Gtk2::\w+(:?::\w+)*)/) {
			$widgets{$1}{$file}++;
		}
	}
}	

# check if we can read all the files listed in the entries.pl file
sub check_files {
	my ($entries) = @_;
	foreach my $entry (@$entries) {
		open my $fh, $entry->{name} or die "Could not open $entry->{name} $!";
		check_files($entry->{more}) if $entry->{more};
	}
}

sub search {
	#print Dumper \@_;
	my $text = $search_entry->get_text;
	print "$text\n";
	print join "\n", _search($text, \@entries); 

}
sub _search {
	my ($text, $entries) = @_;

	my @resp;

	foreach my $entry (@$entries) {
		#$entry->{title}, 
		#$entry->{type}, 
		if (open my $fh, "<", $entry->{name}) {
			if (grep /$text/, <$fh>) {
				push @resp, $entry->{name};
			}
		}
		if ($entry->{more}) {
			push @resp, _search($text, $entry->{more});
		}
	}
	return @resp;
}


=head1 TODO

Disable both execute button and save button for non-executable entries
When saving a file with the name of an already existing file ask if to rewrite ?


Better grouping of the examples in the multi level tree

Syntax highlighting  (using Gtk2::SourceView ?)

Better distribution method (preprocessing an everything in one file ?)

Longer tutorial

Mark clearly on the item list which one is text and which one is code

We might want to run the external application on a fork so the user can run several 
versions at the same time and see the differences.

Have a list of all the signals and jump to files based on signal names ?
Have an index of all the words in the comments and pod sections of the files ?

See also and somehow integrate with 
http://live.gnome.org/GTK2_2dPerl_2fRecipes



=head1 DONE

All the examples from the distrubtion are included

Multi level tree (so the various sections can be in expandable subtree)

Add execute button

Provide an index tables where we list all the Widgets we used in the examples
and where were they used. We might be able to list all the signal handlers
and where were they used.

Code for execution should be taken from the window and we should encourage people to
experiment with the various options. 

Add save button to save the content of the code window (now that we do not have them in separate files)

=cut

