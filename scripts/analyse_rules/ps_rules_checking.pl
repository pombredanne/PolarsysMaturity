#! perl
#
# This script parses the output of PMD and FindBugs output files and builds
# a json file with all rule-related metrics for the PolarSys Maturity
# Assessment process.
#
# Author: Boris Baldassari <boris.baldassari@gmail.com>
#
# Licensing: Eclipse Public License - v 1.0
# http://www.eclipse.org/org/documents/epl-v10.html
# 

use strict;
use warnings;

use Getopt::Long;

use Data::Dumper;
use File::Basename;
use XML::LibXML;
use JSON qw( decode_json );


my $usage = <<EOU;

$0 --pmd-rules=/path/to/pmd_dir --pmd-file=/path/to/xml_file
   --finbugs-rules=/path/to/findbugs_dir --findbugs-file=/path/to/xml_file
   --output=mymetrics.json
 
where:
  -v|--verbose          Be verbose.
  -h|--help             Print usage and exit.
  -pr|--pmd-rules       The directory containing JSON PMD rules definition.
  -pf|--pmd-file        The PMD XML results file with violations.
  -fr|--findbug-rules   The directory containing JSON PMD rules definition.
  -ff|--findbugs-file   The FindBugs XML results file with violations.
  -o|--output           The file to write metrics to (JSON).
  -ov|--output-v        Write violations to specified files (optional).


This script parses the XML output of PMD and FindBugs and builds
a json file with all rule-related metrics for the PolarSys Maturity
Assessment process.

For more information see https://polarsys.org/wiki/MaturityAssessmentRules

EOU

die $usage if (scalar @ARGV < 8);

my $debug = 0;

my (
    $opt_help,
    $opt_verbose,
    $opt_pmd_rules,
    $opt_pmd_file,
    $opt_fb_rules,
    $opt_fb_file,
    $opt_output,
    $opt_output_v,
    );
    

# Parse command-line options
GetOptions(
           'h|help' => \$opt_help,
           'v|verbose' => \$opt_verbose,
           'pr|pmd-rules=s' => \$opt_pmd_rules,
           'pf|pmd-file=s' => \$opt_pmd_file,
           'fr|findbugs-rules=s' => \$opt_fb_rules,
           'ff|findbugs-file=s' => \$opt_fb_file,
           'o|output=s' => \$opt_output,
           'ov|output-v=s' => \$opt_output_v,
    );

if ( not defined($opt_pmd_rules) ) {
    die "Need a directory containing PMD rules definition. (--pmd_rules=/path/to/dir)";
}
#die "PMD rules definition (-pr) must be a directory." if ( not -d $opt_pmd_rules );

if ( not defined($opt_pmd_file) ) {
    die "Need a directory containing PMD XML file. (--pmd_file=/path/to/dir)";
}
#die "PMD file (-pf) must be a file." if ( not -f $opt_pmd_file );

if ( not defined($opt_fb_rules) ) {
    die "Need a directory containing FindBugs rules definition. (--findbugs_rules=/path/to/dir)";
}
#die "FindBugs rules definition (-fr) must be a directory." if ( not -d $opt_fb_rules );

if ( not defined($opt_fb_file) ) {
    die "Need a directory containing FindBugs XML file. (--findbugs_file=/path/to/dir)";
}
#die "FindBugs file (-ff) must be a file." if ( not -f $opt_fb_file );

if (not defined($opt_output)) {
    die "Need a file to write JSON results to. \n";
}

my $time = localtime();
print "\nExecuting $0 on $time.\n";

if (defined($opt_help)) {
    die $usage;
}


my %violations;
my %categories;
my %rules;
my %unknown_rules;
my %metrics = (
    "RULES" => 0,
    "RULES_ANA" => 0, "RKO_ANA" => 0, "ROK_ANA" => 0, "NCC_ANA" => 0, "ROKR_ANA" => 0,
    "RULES_CHA" => 0, "RKO_CHA" => 0, "ROK_CHA" => 0, "NCC_CHA" => 0, "ROKR_CHA" => 0,
    "RULES_REU" => 0, "RKO_REU" => 0, "ROK_REU" => 0, "NCC_REU" => 0, "ROKR_REU" => 0,
    "RULES_REL" => 0, "RKO_REL" => 0, "ROK_REL" => 0, "NCC_REL" => 0, "ROKR_REL" => 0,
    "RULES_TES" => 0, "RKO_TES" => 0, "ROK_TES" => 0, "NCC_TES" => 0, "ROKR_TES" => 0,
    "RULES_RES" => 0, "RKO_CHA" => 0, "ROK_RES" => 0, "NCC_RES" => 0, "ROKR_RES" => 0,
);


#
# Read rules from json files
#

# Get a list of all rule-related files
my @json_pmd_files = <$opt_pmd_rules/*.json>;
my @json_fb_files = <$opt_fb_rules/*.json>;
my @json_files = ( @json_pmd_files, @json_fb_files );

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
    
    my $rules_name = $raw_rules->{'name'};
    my $rules_version = $raw_rules->{'version'};
    print "Rules name: [", $rules_name, "], ";
    print "version: [", $rules_version, "].\n";
    
    my $file_vol_rules;
    foreach my $rule_child (@{$raw_rules->{ 'children' }}) {
	my $rule_mnemo = $rule_child->{ 'mnemo' };
	if ( exists($rule_child->{ 'cat' }) ) {
	    $rules{ $rule_child->{ 'mnemo' } } = $rule_child;
	    print "DBG read ", $rule_child->{ 'mnemo' }, " " if ($debug);
	    print $rule_child->{ 'name' }, "\n" if ($debug);
	    $file_vol_rules++;
	    my @rule_cats = split( ' ', $rule_child->{ 'cat' } );
	    foreach my $rule_cat (@rule_cats) {
		$metrics{ "RULES_" . $rule_cat }++;
	    }
	} else {
	    print "[ERROR] No category defined on $rule_mnemo.\n" if (defined($opt_verbose));
	}
    }
    $vol_rules += $file_vol_rules;
    
    print "Imported $file_vol_rules rules from file.\n\n";
}

print "Imported a total of $vol_rules rules.\n\n";

$metrics{"RULES"} = $vol_rules;


#
# Do basic checks for configuration integrity and consistency
#

# # For each registered rule, check its categories and count the number of 
# # rules for each category (RULES_ANA, RULES_REL, etc.). 
# # If no category is defined, print a warning.
# foreach my $rule_mnemo (keys %rules) {
#     my $rule = $rules{$rule_mnemo};
#     if (exists($rule->{"cat"})) {
#         my @rule_cats = split( ' ', $rule->{"cat"});
#         foreach my $rule_cat (@rule_cats) {
#             $metrics{"RULES_" . $rule_cat}++;
#         }
#     } else {
#         print "[ERROR] No category defined on $rule_mnemo.\n";
#     }
# }


#
# Read violations from FindBugs XML file
#

print "Reading FindBugs XML file [$opt_fb_file]..\n\n";

my $parser = XML::LibXML->new;
my $doc = $parser->parse_file($opt_fb_file);

my @violations_nodes = $doc->findnodes("//BugInstance");

foreach my $violation (@violations_nodes) {
    my $v_name = $violation->getAttribute('type');
    
    if ( exists( $rules{ $v_name } ) ) {

        # Get some information for the violation.
        $violations{ $v_name }{ 'vol' }++;
        $violations{ $v_name }{ 'pri' } = $violation->getAttribute('priority');
    
    
        # Count it against the categories defined
        $violations{ $v_name }{ 'cat' } = $rules{ $v_name }->{ 'cat' };
        foreach my $cat (split(' ', $rules{ $v_name }->{ 'cat' })) {
            $categories{ $cat }->{ 'vol' }++;
            $categories{ $cat }->{ $v_name }++;
        }
    } else {
        $unknown_rules{ $v_name }++;
        print "[WARN] Could not find rule $v_name.\n" if ($debug);
    }
}


#
# Read violations from PMD XML file
#

print "Reading PMD XML file [$opt_fb_file]..\n\n";

$doc = $parser->parse_file($opt_pmd_file);

@violations_nodes = $doc->findnodes("//violation");

foreach my $violation (@violations_nodes) {

    my $v_name = $violation->getAttribute('rule');

    # Get some information for the violation.
    $violations{ $v_name }{ 'vol' }++;
    $violations{ $v_name }{ 'pri' } = $violation->getAttribute('priority');
    
    # Count it against the categories defined
    if ( exists( $rules{ $v_name } ) ) {
        $violations{ $v_name }{ 'cat' } = $rules{ $v_name }->{ 'cat' };
        foreach my $cat (split(' ', $rules{ $v_name }->{ 'cat' })) {
            $categories{ $cat }->{ 'vol' }++;
            $categories{ $cat }->{ $v_name }++;
        }
    } else {
        $unknown_rules{ $v_name }++;
        print "ERR Could not find rule $v_name.\n" if ($debug);
    }
}


my $length = scalar keys %violations;

print "\nWorking on category metrics...\n";
foreach my $cat (sort keys %categories) {
    if (defined($opt_verbose)) {
	print '* ' , $cat, ' violated ', $categories{ $cat }->{ 'vol' }, " times.\n";
    }
    $metrics{ 'NCC_' . $cat } = $categories{ $cat }->{ 'vol' };
    
    # Children are violated rules, excepted for the 'vol' attribute which
    # is the volume of violations for the category.
    my $cat_length = scalar keys %{$categories{ $cat }};
    $metrics{ 'RKO_' . $cat } = $cat_length - 1;
    $metrics{ 'ROK_' . $cat } = $metrics{ 'RULES_' . $cat } - $metrics{ 'RKO_' . $cat };
    $metrics{ 'ROKR_' . $cat } = 100 * $metrics{ 'ROK_' . $cat } / $metrics{ 'RULES_' . $cat };
}

if (defined($opt_verbose)) {
    
    print "Found $length rules violated.\n";

    print "\nDisplaying violations...\n";
    foreach my $violation (keys %violations) {
	print "* " , $violation, " ", $violations{ $violation }{ 'vol' }, " priority ", 
	$violations{ $violation }{ 'pri' }, ".\n";
    }
    
    print "\nDisplaying unknown rules...\n";
    foreach my $rule (keys %unknown_rules) {
	print "* " , $rule, " violated ", $unknown_rules{ $rule }, " times.\n";
    }
}

# Write violations to a file if demanded
if (defined($opt_output_v) && $opt_output_v =~ m!\S+!) {
    print "Writing violations to file [$opt_output_v].\n";
    my $json_violations;
    $json_violations = "{\n";
    $json_violations .= "    \"name\": \"Project violations\",\n";
    $json_violations .= "    \"children\": [\n";
    my $start = 1;
    foreach my $violation (keys %violations) {
	if ( exists( $rules{$violation} ) ) {
	    if (exists($rules{ "$violation" }->{ 'cat' })) {
		my @cats = split(' ', $rules{ "$violation" }->{ 'cat' });
		my $cat = $cats[0];
		my $vol = $violations{$violation}->{'vol'};
		print "Working on violation $violation: $vol.\n" if (defined($opt_verbose));
		my $tmp_m = "        {\n";
		$tmp_m   .= "            \"name\": \"$violation\",\n";
		$tmp_m   .= "            \"cat\": \"$cat\",\n";
		$tmp_m   .= "            \"value\": \"$vol\"\n";
		$tmp_m   .= "        }";
		if ($start) {
		    $json_violations = join( "\n", $json_violations, $tmp_m);
		    $start = 0;
		} else {
		    $json_violations = join( ", \n", $json_violations, $tmp_m);
		}
	    } else {
		print "Category not defined for $violation.\n" if (defined($opt_verbose));
	    }
	}
    }
    $json_violations .= "    ]\n";
    $json_violations .= "}\n";
    
    # Write string to specified file
    open( FHV, ">$opt_output_v" ) or die "Could not open $opt_output_v.\n";
    print FHV $json_violations;
    close FHV;
}

# Write metrics to a file
print "Writing metrics to file [$opt_output]...\n";
my $json_out;
$json_out = "{\n";
$json_out .= "    \"name\": \"Project metrics\",\n";
$json_out .= "    \"children\": [\n";
my @full_json_out;
foreach my $metric (sort keys %metrics) {
    print "Working on $metric: $metrics{$metric}.\n" if (defined($opt_verbose));
    my $tmp_m = "        {\n";
    $tmp_m   .= "            \"name\": \"$metric\",\n";
    $tmp_m   .= "            \"value\": \"$metrics{$metric}\"\n";
    $tmp_m   .= "        }";
    push( @full_json_out, $tmp_m );
}
$json_out .= join( ", \n", @full_json_out);
$json_out .= "\n    ]\n";
$json_out .= "}\n";


open( FHOUT, ">$opt_output" ) or die "Could not open $opt_output.\n";
print FHOUT $json_out;
close FHOUT;

print "\n\n";
