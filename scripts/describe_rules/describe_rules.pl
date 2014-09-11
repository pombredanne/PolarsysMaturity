#! /usr/bin/perl

# Displays the information about rules in html and mediawiki formats.
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
Usage:
\$ $0 dir_rules

creates an html and mediawiki representation of the rules
described in the json files contained in the directory
given as parameter.

EOU

die $usage if (scalar @ARGV != 1);

my $dir_rules = shift;

my $debug = 0;
my %flat_rules;

my $full_mw_rules;
my $full_csv_rules;


## Functions

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

# describes a rule
# params: 
#   $ the mnemo of the rule
sub describe_rule($) {
    my $mnemo = shift;

    if (not exists $flat_rules{$mnemo}) {
        die "Could not find rule (internal inconsistency).\n";
    }

    my $rule = $flat_rules{$mnemo};
    my $rule_name = $rule->{"name"};
    my $rule_pri = $rule->{"priority"};
    my $rule_cats = $rule->{"cat"};
    
    my @rule_desc = @{$rule->{"desc"}};

    my $text = "<h4>$rule_name ($mnemo)</h4>\n";
    $text .= "<p class=\"desc\">Category: $rule_cats</p>\n";
    $text .= "<p class=\"desc\">Priority: $rule_pri</p>\n";

    $full_mw_rules .= "* $rule_name ($mnemo)\n";
    $full_mw_rules .= "** Category: $rule_cats\n";
    $full_mw_rules .= "** Priority: $rule_pri\n";
    
    $full_csv_rules .= "$mnemo,$rule_pri,$rule_cats\n";

    $text .= "<p class=\"desc\">Description:</p>\n";
    $full_mw_rules .= "** Description:\n";
    foreach my $p (@rule_desc) {
        $text .= "<p class=\"desc\">$p</p>\n";
        $full_mw_rules .= ":$p\n";
    }
    
    $full_mw_rules .= "\n";
    return $text;
} 



#
# Read rules from json files in the rules directory
#
my @json_files = <$dir_rules/*.json>;

my $vol_rules;
foreach my $file_rules (@json_files) {
    
    print "Reading rules file $file_rules..\n";

    # Open json file
    my $json_rules;
    do { 
        local $/;
        open my $fh, "<", $file_rules;
        $json_rules = <$fh>;
    };
    
    # Decode the entire JSON
    my $raw_rules = decode_json( $json_rules );
    
    my $rules_name = $raw_rules->{"name"};
    my $rules_version = $raw_rules->{"version"};
    print "Rules name: ", $rules_name, "\n";
    print "Rules version: ", $rules_version, "\n";
    
    my $file_vol_rules;
    foreach my $rule_child (@{$raw_rules->{"children"}}) {
        $flat_rules{$rule_child->{"mnemo"}} = $rule_child;
        $file_vol_rules++;
    }
    $vol_rules += $file_vol_rules;
    
    print "Imported $file_vol_rules rules from file.\n\n";
}
#print Dumper( %flat_rules ) if ($debug);

# $full_text_* contain the full html page string for rules and concepts.
my $full_text_rules = "<!DOCTYPE html><body>\n";
$full_text_rules .= "<link rel=\"stylesheet\" type=\"text/css\" href=\"styles.css\"/>\n";
$full_text_rules .= "<h1>List of rules for the PolarSys Maturity Assessment quality model</h1>\n";


# Loop through rules
print "\n# Looping through rules...\n";
my $rules_vol = 0;
foreach my $rule ( keys %flat_rules ) {

    my $rule_name = $flat_rules{$rule}{"name"};
    print "Working on $rule_name: $rule.\n";

    #$full_text_concepts .= "<h2>Concept name</h2>\n";
    #$full_mw_concepts .= "== Concept: $concept_name ==\n\n";

    $full_text_rules .= &describe_rule($rule) or die "Cannot find rule '$rule_name'.";
    $rules_vol++;
}
print "Total number of rules: $rules_vol.\n";

# Close html tags in output
$full_text_rules .= "</body></html>\n";

# Write results to html file.
print "\nWriting html description to target/rules.html.\n";
&write_file("target/rules.html", $full_text_rules);

# Write results to file for mediawiki.
print "Writing mediawiki formatting to target/rules.mw.\n";
&write_file("target/rules.mw", $full_mw_rules);

# Write results to csv file.
print "Writing csv formatting to target/rules.csv.\n";
&write_file("target/rules.csv", $full_csv_rules);



