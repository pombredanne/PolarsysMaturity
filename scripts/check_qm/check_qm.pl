#! /usr/bin/perl

# Applies various integrity checks on the different files that compose the 
# PolarSys quality model. Warns for unconsistent metrics combinations, missing
# attributes, etc.
#
# Author: Boris Baldassari <boris.baldassari@gmail.com>
#
# Licensing: Eclipse Public License - v 1.0
# http://www.eclipse.org/org/documents/epl-v10.html

use strict;
use warnings;
use Data::Dumper;
use JSON qw( decode_json );

my $usage = <<EOU;
$0 json_qm json_concepts json_metrics

Applies various checks to the quality model, concepts and metrics 
for the PolarSys Maturity task project.

EOU

die $usage if (scalar @ARGV != 3);

my $file_qm = shift;
my $file_concepts = shift;
my $file_metrics = shift;
my ($qm, $concepts, $metrics);

my $debug = 0;
my %flat_metrics;


## Functions

# recursive function to find leaves of a tree.
# params: 
#   $ a hash reference to the tree.
sub find_leaves($) {
    my $tree = shift;

    print "Traversing ", $tree->{"name"}, "\n" if ($debug);

    if (exists($tree->{"children"})) {
	foreach my $child (@{$tree->{"children"}}) {
	    &find_leaves($child);
	}
    } else {
	my $name = $tree->{"mnemo"};
	$flat_metrics{$name} = $tree;
    }
}


# Read files
# params: 
#   $ the name of the file to be slurp.
sub read_file($) {
    my $filename = shift;

    do { 
        local $/;
        open my $fh, "<", $filename;
        return <$fh>;
    };
}


# Check consistency of a metric
# params:
#   $ the mnemo string of the metric to be checked
sub check_metric($) {
    my $mnemo = shift;

    print "Checking metric $mnemo.\n";

    return -1 if (not exists $flat_metrics{$mnemo});
    my $metric = $flat_metrics{$mnemo};

    if ( not exists $metric->{"name"} ) {
	print "[ERR] metric $mnemo has no question.\n";
    }
    if ( not exists $metric->{"description"} ) {
	print "[ERR] metric $mnemo has no question.\n";
    }
    if ( not exists $metric->{"question"} ) {
	print "[ERR] metric $mnemo has no question.\n";
    }
    if ( not exists $metric->{"datasource"} ) {
	print "[ERR] metric $mnemo has no datasource.\n";
    }

    if ( exists $metric->{"composition"} ) {
	print "[ERR] metric $mnemo has a composition node.\n";
    }
    
    return 1;
} 


# Check consistency of a concept
# params:
#   $ a hash ref to the concept to be checked
sub check_concept($) {
    my $concept = shift;

    my $mnemo;

    if ( not exists $concept->{"mnemo"} ) {
	print "[ERR] concept has no mnemo.\n";
    } else { 
	$mnemo = $concept->{"mnemo"};
    }
    if ( not exists $concept->{"name"} ) {
	print "[ERR] concept $mnemo has no name.\n";
    }
    if ( not exists $concept->{"description"} ) {
	print "[ERR] concept $mnemo has no description.\n";
    }
    if ( not exists $concept->{"question"} ) {
	print "[ERR] concept $mnemo has no question.\n";
    }
    if ( not exists $concept->{"composition"} ) {
	print "[ERR] concept $mnemo has no composition.\n";
    } else {
	my @compo_metrics =  split( " ", $concept->{"composition"} );
	# Detect if we miss some base metrics to compute this derived concept
	foreach my $compo_metric (@compo_metrics) {
	    if ( not exists $flat_metrics{$compo_metric} ) {
		print "WARN: Missing $compo_metric to compute $mnemo.\n";
	    }
	}
    }

} 


# Check consistency of the qm structure
# params:
#   $ a hash ref to the qm tree to be checked
sub check_qm($) {
    my $tree = shift;

    # Check for mnemo first
    if ( not exists $tree->{"mnemo"} ) { 
	print "[ERR] No mnemo :-/ .\n";
    } else {
	print "# Checking node " . $tree->{"mnemo"} . " ";
    }

    print "Checking type.\n" if ($debug);
    if ( exists $tree->{"type"} ) {
	if ( $tree->{"type"} ne "attribute" ) {
            print " [KO]\n";
	    print "Not an attribute.\n" if ($debug);
	    return;
	} else {
	    print " [OKxs]\n";
	}
    } else {
	print "[ERR] No type on " . $tree->{"mnemo"} . ".\n";
    }

    print "Checking name.\n" if ($debug);
    if ( not exists $tree->{"name"} ) { 
	print "[ERR] No name.\n";
    } 

    print "Checking description.\n" if ($debug);
    if ( not exists $tree->{"description"} ) { 
	print "[ERR] No description.\n";
    }

    # recursively go through children.
    if (exists($tree->{"children"})) {
	foreach my $child (@{$tree->{"children"}}) {
	    &check_qm($child);
	}
    } 
}


## Read metrics file

# Open file and read.
my $json_qm = &read_file($file_qm);
my $json_concepts = &read_file($file_concepts);
my $json_metrics = &read_file($file_metrics);

# Decode the entire JSON
$qm = decode_json( $json_qm );
$concepts = decode_json( $json_concepts );
$metrics = decode_json( $json_metrics );

# Extract leafes -- used later on to easily find metrics.
&find_leaves( $metrics );

print Dumper( %flat_metrics ) if ($debug);


# Check metrics definition file
print "# Checking metrics definition file...\n\n";
foreach my $repo ( @{$metrics->{"children"}} ) {

    my $repo_name = $repo->{"name"};
    print "# Checking $repo_name.\n";

    # Print base metrics
    my $base_metrics_vol = 0;
    for my $tmp_metric ( @{$repo->{"children"}} ) {
	my $metric_mnemo = $tmp_metric->{"mnemo"};
	$base_metrics_vol++;
	&check_metric($metric_mnemo) or die "Cannot find metric '$metric_mnemo'.";
    }
    print "Number of base metrics: $base_metrics_vol.\n\n";
}


# Test concepts definition file
print "# Checking concepts definition file...\n\n";
my $compo_concepts_vol = 0;
for my $tmp_concept ( @{$concepts->{"children"}} ) {
    &check_concept($tmp_concept);
    $compo_concepts_vol++;
}
print "Number of concepts: $compo_concepts_vol.\n\n";
    

# Check qm definition file
print "# Checking quality model definition...\n\n";
&check_qm($qm);

print # Checks done.\n";
