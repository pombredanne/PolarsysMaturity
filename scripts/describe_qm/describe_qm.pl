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
$0 json_metrics

creates an html and mediawiki representation of the metric 
json file passed as parameter.

EOU

die $usage if (scalar @ARGV != 1);

my $file_metrics = shift;

my $debug = 0;
my %flat_metrics;
my $full_mw;


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

    return -1 if (not exists $flat_metrics{$mnemo});
    my $metric = $flat_metrics{$mnemo};
    my $metric_name = $metric->{"name"};
    my $metric_desc = $metric->{"description"};

    my $text = "<h4>$metric_name ($mnemo)</h4>\n";
    $text .= "<p class=\"desc\">Description: $metric_desc</p>\n";

    $full_mw .= "* $metric_name ($mnemo)\n";
    $full_mw .= ":Description: $metric_desc\n";

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
	$full_mw .= ":Composed of $compo.\n";
    }

    $full_mw .= "\n";
    return $text;
} 


## Read metrics file

# Open file and read.
print "\nReading metrics files...\n";
my $json_metrics;
do { 
    local $/;
    open my $fh, "<", $file_metrics;
    $json_metrics = <$fh>;
};

# Decode the entire JSON
my $metrics = decode_json( $json_metrics );

# Extract leafes
&find_leaves( $metrics );

print Dumper( %flat_metrics ) if ($debug);

# $full_text contains the full html page string.
my $full_text = "<!DOCTYPE html><body>\n";
$full_text .= "<link rel=\"stylesheet\" type=\"text/css\" href=\"styles.css\"/>\n";
$full_text .= "<h1>List of metrics for the PolarSys Maturity Assessment quality model</h1>\n";

# Loop through metric's repos
foreach my $repo ( @{$metrics->{"children"}} ) {

    my $repo_name = $repo->{"name"};
    print "\n# $repo_name.\n";

    $full_text .= "<h2>Repository $repo_name</h2>\n";
    $full_mw .= "= Repository: $repo_name =\n\n";

    # Print derived (composed) metrics (i.e. concepts)
    $full_text .= "<h3>Composed metrics</h3>\n";
    $full_mw .= "\n== Derived metrics ==\n\n";
    my $compo_metrics_vol = 0;
    for my $tmp_metric ( @{$repo->{"children"}} ) {
	my $metric_mnemo = $tmp_metric->{"mnemo"};
	if ( exists $flat_metrics{$metric_mnemo}->{"composition"} ) {
	    $compo_metrics_vol++;
	    $full_text .= &describe_metric($metric_mnemo) or die "Cannot find metric '$metric_mnemo'.";
	}
    }
    print "Total number of derived metrics: $compo_metrics_vol.\n";
    
    # Print base metrics
    $full_text .= "<h3>Base metrics</h3>\n";
    $full_mw .= "\n== Base metrics ==\n\n";
    my $base_metrics_vol = 0;
    for my $tmp_metric ( @{$repo->{"children"}} ) {
	my $metric_mnemo = $tmp_metric->{"mnemo"};
	if ( not exists $flat_metrics{$metric_mnemo}->{"composition"} ) {
	    $base_metrics_vol++;
	    $full_text .= &describe_metric($metric_mnemo) or die "Cannot find metric '$metric_mnemo'.";
	}
    }
    print "Total number of base metrics: $base_metrics_vol.\n";
}

# Close html tags in output
$full_text .= "</body></html>\n";

# Write results to html file.
print "\nWriting html description to target/metrics.html.\n";
&write_file("target/metrics.html", $full_text);

# Write results to file for mediawiki.
print "Writing mediawiki formatting to target/metrics.mw.\n\n";
&write_file("target/metrics.mw", $full_mw);



