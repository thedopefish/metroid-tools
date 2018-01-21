#!/usr/bin/perl
# MIDI filtering thingy
# by thedopefish, 2018

use strict;
use MIDI;

#################
# Configuration #
#################

my $debug = 0; # enable to get spammed with debugging messages

my $min_duration = 2; # in ticks; each MIDI defines its own ticks per quarter note
my $max_duration = 1000;

my $min_volume = 0; # volume range is 0-127
my $max_volume = 127;

my $min_note = 48; # 60 is middle C, 0 is the lowest C, 127 is the highest G
my $max_note = 95;

#############
# Functions #
#############

# convert the event list into a format that's easier to work with
sub parse_midi_track
{
	my($arrayref) = @_;
	my @events = @{$arrayref};

	my @note_queue;
	my $total_ticks = 0;
	my $i = 0;

	foreach my $e (@events) {
		my($event_type, $delta, $channel, $note, $volume) = @$e;
		print "\t$event_type \t$delta\t$channel\t$note\t$volume\n" if($debug);

		$total_ticks += $delta;
		$note_queue[$i++] = {
			"event" => $e,
			"event_type" => $event_type,
			"channel" => $channel,
			"note" => $note,
			"volume" => $volume,
			"delta" => $delta,
			"absolute_time" => $total_ticks,
		};
	}

	@note_queue;
}

# find the previous matching note_on event for the specified note_off event
sub find_orig_note
{
	my($arrayref, $note, $end_note_index) = @_;
	my @note_array = @{$arrayref};
	my %note = %{$note};

	my $i;
	for($i = $end_note_index; $i >= 0; $i--) {
		if( $note_array[$i]->{"event_type"} eq "note_on" &&
			$note_array[$i]->{"channel"} == $note{"channel"} &&
			$note_array[$i]->{"note"} == $note{"note"} )
	   	{
			last;
		}
	}

	$i;
}

# apply filtering logic to suppress unwanted notes
sub apply_filters
{
	my($arrayref) = @_;
	my @note_queue = @{$arrayref};

	my $i = 0;
	foreach my $note (@note_queue) {
		if($note->{"event_type"} eq "note_off") {
			my $orig_note_index = find_orig_note(\@note_queue, $note, $i);
			warn "Unmateched note_off found at index $i" unless $orig_note_index >= 0;
			my $orig_note = $note_queue[$orig_note_index];

			my $true_delta = $note->{"absolute_time"} - $orig_note->{"absolute_time"};
			if($true_delta < $min_duration || $true_delta > $max_duration) {
				print "ate note for duration $true_delta\n" if($debug);
				$orig_note->{"skip"} = 1;
				$note->{"skip"} = 1;
			} elsif($note->{"volume"} < $min_volume || $note->{"volume"} > $max_volume) {
				print "ate note for volume " . $note->{"volume"} . "\n" if($debug);
				$orig_note->{"skip"} = 1;
				$note->{"skip"} = 1;
			} elsif($note->{"note"} < $min_note || $note->{"note"} > $max_note) {
				print "ate note for pitch " . $note->{"note"} . "\n" if($debug);
				$orig_note->{"skip"} = 1;
				$note->{"skip"} = 1;
			}
		}

		$i++;
	}

	@note_queue;
}

# reconstruct the events list, containing only the desired notes
sub rebuild_midi_events
{
	my($arrayref) = @_;
	my @note_queue = @{$arrayref};

	my @after_events;
	my $total_ticks = 0;
	foreach my $note (@note_queue) {
		unless(defined $note->{"skip"}) {
			my $delta = $note->{"absolute_time"} - $total_ticks;

			my @next_note = @{$note->{"event"}};
			$next_note[1] = $delta;

			push @after_events, \@next_note;

			$total_ticks = $note->{"absolute_time"};
		}
	}

	@after_events;
}

########
# Main #
########

my $input_filename = $ARGV[0] or die("Please specify a MIDI file");
my $output_filename = $ARGV[1] || "output.midi";

my $song = MIDI::Opus->new({from_file => $input_filename});
print "Read $input_filename\n";
$song->dump();

my @tracks = $song->tracks();
foreach my $t (@tracks) {
	my @events = $t->events();
	my @note_queue = parse_midi_track(\@events);

	apply_filters(\@note_queue);

	my @after_events = rebuild_midi_events(\@note_queue);
	$t->events(@after_events);
}

$song->write_to_file($output_filename);
print "Wrote $output_filename\n";

