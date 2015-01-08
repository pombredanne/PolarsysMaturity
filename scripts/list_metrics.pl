#! /usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

use JSON qw( decode_json );

my $debug = 0;

my $usage = "$0 json_metrics ";
die $usage if (scalar @ARGV != 1);

my $file_metrics = shift;

my @leaves;

sub find_leaves($) {
    my $tree = shift;

    print "Traversing ", $tree->{"name"}, "\n" if ($debug);

    if (exists($tree->{"children"})) {
	foreach my $child (@{$tree->{"children"}}) {
	    &find_leaves($child);
	}
    } else {
	push( @leaves, $tree );
    }
}


# Open json file
my $json_metrics;
do { 
    local $/;
    open my $fh, "<", $file_metrics;
    $json_metrics = <$fh>;
};

# Decode the entire JSON
my $metrics = decode_json( $json_metrics );

# Display metrics and their values.
#print Dumper $metrics;

&find_leaves($metrics);
#print Dumper( @leaves );
my %metrics_final;
foreach my $leaf (@leaves) {
    my $name = $leaf->{"name"} || "";
    my $mnemo = $leaf->{"mnemo"} || "";
    my $desc = $leaf->{"description"} || "";
    $metrics_final{$mnemo} = $name;
#    print "Metric [$name] [$mnemo] [$desc].\n";
}

foreach my $metric_final (sort keys %metrics_final) {
    my $mnemo = $metric_final;
    my $name = $metrics_final{$mnemo};
    print "[$mnemo] [$name]\n";
#    print "Metric [$name] [$mnemo] [$desc].\n";
}

