#!/usr/bin/perl

use strict;
use MIDI;

##### quick & dirty config
my $min_duration = 40;
my $max_duration = 1000;

my $min_volume = 0;
my $max_volume = 100;
#####

my $input_filename = $ARGV[0] or die("Please specify a MIDI file");
my $output_filename = $ARGV[1] || "output.midi";

my $song = MIDI::Opus->new({from_file => $input_filename});
print "Read $input_filename\n";
my @tracks = $song->tracks();
#print "This song has " . (scalar @tracks) . " track(s).\n";

my $track_index = 0;
foreach my $t (@tracks) {
	#print "Track $track_index:\n";

	my @events = $t->events();
	my @after_events;
	my $last_note;
	foreach my $e (@events) {
		my($event_type, $delta, $channel, $note, $volume) = @$e;
		#print "\t$event_type\t$delta\t$channel\t$note\t$volume\n";
		if($event_type eq "note_on") {
			$last_note = $e;
		} elsif($event_type eq "note_off") {
			if($delta < $min_duration || $delta > $max_duration) {
				# get rekt note
			} elsif($volume < $min_volume || $volume > $max_volume) {
				# get rekt note
			} else {
				push @after_events, $last_note;
				push @after_events, $e;
			}
		} else {
			push @after_events, $e
		}
	}
	$t->events(@after_events);

	$track_index++;
}

$song->write_to_file($output_filename);
print "Wrote $output_filename\n";

