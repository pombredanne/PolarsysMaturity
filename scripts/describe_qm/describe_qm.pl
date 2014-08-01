#! /usr/bin/perl

# Displays the metrics information in html and mediawiki formats.
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
$0 json concepts json_metrics

creates an html and mediawiki representation of the metric 
and concepts json file passed as parameter.

EOU

die $usage if (scalar @ARGV != 2);

my $file_concepts = shift;
my $file_metrics = shift;

my $debug = 0;
my %flat_metrics;

my $full_mw_metrics;
my $full_mw_concepts;


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


# write a string to a file
# params: 
#   $ the name of the file to write to
#   $ the string to be written in the file
sub write_file($$) {
    my $file_name = shift;
    my $content = shift;

    open( my $fh, ">", $file_name ) or die "Cannot open $file_name for writing.";
    print $fh $content;
    close $fh;
}

# describes a metric
# params: 
#   $ the mnemo of the metric
sub describe_metric($) {
    my $mnemo = shift;

    if (not exists $flat_metrics{$mnemo}) {
	die "Could not find metric (internal inconsistency).\n";
    }

    my $metric = $flat_metrics{$mnemo};
    my $metric_name = $metric->{"name"};
    my $metric_desc = $metric->{"description"};

    my $text = "<h4>$metric_name ($mnemo)</h4>\n";
    $text .= "<p class=\"desc\">Description: $metric_desc</p>\n";

    $full_mw_metrics .= "* $metric_name ($mnemo)\n";
    $full_mw_metrics .= ":Description: $metric_desc\n";

    if ( exists $metric->{"composition"} ) {
	my @compo_metrics =  split( " ", $metric->{"composition"} );
	# Detect if we miss some base metrics to compute this derived metric
	foreach my $compo_metric (@compo_metrics) {
	    if ( not exists $flat_metrics{$compo_metric} ) {
		print "WARN: Missing $compo_metric to compute $mnemo.\n";
	    }
	}
	my $compo = join( ", ", @compo_metrics);
	$text .= "<p>Composed of $compo.</p>\n";
	$full_mw_metrics .= ":Composed of $compo.\n";
    }

    $full_mw_metrics .= "\n";
    return $text;
} 

# describes a concept
# params: 
#   $ a reference to the concept
sub describe_concept($) {
    my $concept = shift;

    my $concept_mnemo = $concept->{"mnemo"};
    my $concept_name = $concept->{"name"};
    my $concept_desc = $concept->{"description"};

    my $text = "<h4>$concept_name ($concept_mnemo)</h4>\n";
    $text .= "<p class=\"desc\">Description: $concept_desc</p>\n";

    $full_mw_concepts .= "* $concept_name ($concept_mnemo)\n";
    $full_mw_concepts .= ":Description: $concept_desc\n";

    if ( exists $concept->{"active"} ) {
	my $concept_active = $concept->{"active"};
	if ( $concept_active eq "true" ) {
	    $full_mw_concepts .= ":Concept is <b>active</b>.\n";
	    $text .= "<p class=\"desc\">Concept is <b>active</b>.</p>\n";
	} else {
	    $full_mw_concepts .= ":Concept is <b>inactive</b> for now.\n";
	    $text .= "<p class=\"desc\">Concept is <b>inactive</b> for now.</p>\n";
	}
    } else {
	print "[ERR] Could not find active attribute on concept node [$concept_mnemo]!\n";	
    }

    if ( exists $concept->{"composition"} ) {
	my @compo_metrics =  split( " ", $concept->{"composition"} );
	# Detect if we miss some base metrics to compute this derived concept
	foreach my $compo_metric (@compo_metrics) {
	    if ( not exists $flat_metrics{$compo_metric} ) {
		print "WARN: Missing $compo_metric to compute $concept_mnemo.\n";
	    }
	}
	my $compo = join( ", ", @compo_metrics);
	$text .= "<p>Composed of $compo.</p>\n";
	$full_mw_concepts .= ":Composed of $compo.\n";
    } else {
	print "[ERR] Could not find composition attribute on concept node [$concept_mnemo]!\n";
    }

    $full_mw_concepts .= "\n";
    return $text;
} 


## Read metrics file

# Open file and read.
print "\nReading metrics files...\n";
my $json_metrics;
do { 
    local $/;
    open my $fhm, "<", $file_metrics;
    $json_metrics = <$fhm>;
};

# Decode the entire JSON
my $metrics = decode_json( $json_metrics );

print "Reading concepts files...\n\n";
my $json_concepts;
do { 
    local $/;
    open my $fhc, "<", $file_concepts;
    $json_concepts = <$fhc>;
};

# Decode the entire JSON
my $concepts = decode_json( $json_concepts );

# Extract leafes
&find_leaves( $metrics );

print Dumper( %flat_metrics ) if ($debug);

# $full_text_* contain the full html page string for metrics and concepts.
my $full_text_metrics = "<!DOCTYPE html><body>\n";
$full_text_metrics .= "<link rel=\"stylesheet\" type=\"text/css\" href=\"styles.css\"/>\n";
$full_text_metrics .= "<h1>List of metrics for the PolarSys Maturity Assessment quality model</h1>\n";

my $full_text_concepts = "<!DOCTYPE html><body>\n";
$full_text_concepts .= "<link rel=\"stylesheet\" type=\"text/css\" href=\"styles.css\"/>\n";
$full_text_concepts .= "<h1>List of concepts for the PolarSys Maturity Assessment quality model</h1>\n";

# Loop through metric's repos
print "# Looping through metrics...\n";
foreach my $repo ( @{$metrics->{"children"}} ) {

    my $repo_name = $repo->{"name"};
    print "\n# $repo_name.\n";

    $full_text_metrics .= "<h2>Repository $repo_name</h2>\n";
    $full_mw_metrics .= "= Repository: $repo_name =\n\n";
    
    # Print base metrics
    my $base_metrics_vol = 0;
    for my $tmp_metric ( @{$repo->{"children"}} ) {
	my $metric_mnemo = $tmp_metric->{"mnemo"};
	if ( not exists $flat_metrics{$metric_mnemo}->{"composition"} ) {
	    $base_metrics_vol++;
	    $full_text_metrics .= &describe_metric($metric_mnemo) or die "Cannot find metric '$metric_mnemo'.";
	}
    }
    print "Total number of base metrics: $base_metrics_vol.\n";
}

# Loop through concepts
print "\n# Looping through concepts...\n";
my $compo_concepts_vol = 0;
foreach my $concept_tree ( @{$concepts->{"children"}} ) {

    my $concept_name = $concept_tree->{"name"};
    print "\nWorking on $concept_name.\n";

    $full_text_concepts .= "<h2>Concept name</h2>\n";
    $full_mw_concepts .= "== Concept: $concept_name =\n\n";

    $full_text_concepts .= &describe_concept($concept_tree) or die "Cannot find concept '$concept_name'.";
	    $compo_concepts_vol++;

    # Print metrics used by concept
    my @tmp_metrics = split( ' ', $concept_tree->{"composition"} );
    for my $tmp_metric ( @tmp_metrics) {
	my $metric_mnemo = $tmp_metric;
	if ( exists $flat_metrics{$metric_mnemo}->{"composition"} ) {
	    $full_text_concepts .= &describe_metric($metric_mnemo) or die "Cannot find metric '$metric_mnemo'.";
	}
    }
}
print "Total number of concepts: $compo_concepts_vol.\n";

# Close html tags in output
$full_text_metrics .= "</body></html>\n";
$full_text_concepts .= "</body></html>\n";

# Write results to html file.
print "\nWriting html description to target/metrics.html.\n";
&write_file("target/metrics.html", $full_text_metrics);

print "Writing html description to target/concepts.html.\n\n";
&write_file("target/concepts.html", $full_text_concepts);

# Write results to file for mediawiki.
print "Writing mediawiki formatting to target/metrics.mw.\n";
&write_file("target/metrics.mw", $full_mw_metrics);

print "Writing mediawiki formatting to target/concepts.mw.\n\n";
&write_file("target/concepts.mw", $full_mw_concepts);



