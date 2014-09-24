#! perl
#
#
#
#
#

use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use XML::LibXML;
use JSON qw( decode_json );

# This can be changed
my $dir_rules = "../findbugs/rules";
my $debug = 0;

my $usage = <<EOU;
$0 findbugs_output.xml

EOU

die $usage if (scalar @ARGV != 1);

my $file_xml = shift;

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
        $rules{$rule_child->{"mnemo"}} = $rule_child;
        $file_vol_rules++;
    }
    $vol_rules += $file_vol_rules;
    
    print "Imported $file_vol_rules rules from file.\n\n";
}

$metrics{"RULES"} = $vol_rules;

# Do some computations on the rules
my %vol_rules;
foreach my $rule_mnemo (keys %rules) {
    my $rule = $rules{$rule_mnemo};
    if (exists($rule->{"cat"})) {
        my @rule_cats = split( ' ', $rule->{"cat"});
        foreach my $rule_cat (@rule_cats) {
            $metrics{"RULES_" . $rule_cat}++;
        }
    } else {
        print "Error: No category defined on $rule_mnemo.\n";
    }
}

    
#
# Read violations from xml file
#

my $parser = XML::LibXML->new;
my $doc = $parser->parse_file($file_xml);

my @violations_nodes = $doc->findnodes("//BugInstance");
my $rkos;

foreach my $violation (@violations_nodes) {
    $violations{ $violation->getAttribute('type') }{ 'vol' }++;
    $violations{ $violation->getAttribute('type') }{ 'pri' } = $violation->getAttribute('priority');
    my $v_name = $violation->getAttribute('type');
    
    if ( exists( $rules{"$v_name"} ) ) {
        $violations{ $v_name }{ 'cat' } = $rules{"$v_name"}->{"cat"};
        foreach my $cat (split(' ', $rules{ "$v_name" }->{ 'cat' })) {
            $categories{$cat}->{'vol'}++;
            $categories{$cat}->{$v_name}++;
        }
    } else {
        $unknown_rules{$v_name}++;
        print "ERR Could not find rule $v_name.\n" if ($debug);
    }
}

print "Displaying violations...\n";
foreach my $violation (keys %violations) {
    print "* " , $violation, " ", $violations{ $violation }{ 'vol' }, " priority ", 
          $violations{ $violation }{ 'pri' }, ".\n";
}
my $length = scalar keys %violations;
print "Found $length rules violated.\n";

# Write violations to a file
my $out_violations_name = $file_xml;
$out_violations_name =~ s/.xml$/_violations.json/;
$out_violations_name = basename( $out_violations_name );

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
	    print "Working on $violation: $vol.\n";
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
	    print "Category not defined for $violation.\n";
	}
    }
}
$json_violations .= "    ]\n";
$json_violations .= "}\n";


open( FHV, ">$out_violations_name" ) or die "Could not open $out_violations_name.\n";
print FHV $json_violations;
close FHV;


print "\nDisplaying categories...\n";
foreach my $cat (sort keys %categories) {
    print '* ' , $cat, ' violated ', $categories{ $cat }->{ 'vol' }, " times.\n";
    $metrics{ 'NCC_' . $cat } = $categories{ $cat }->{ 'vol' };
    
    # Children are violated rules, except for the 'vol' attribute which
    # is the volume of violations for the category.
    my $cat_length = scalar keys %{$categories{ $cat }};
    $metrics{ 'RKO_' . $cat } = $cat_length - 1;
    $metrics{ 'ROK_' . $cat } = $metrics{ 'RULES_' . $cat } - $metrics{ 'RKO_' . $cat };
    $metrics{ 'ROKR_' . $cat } = 100 * $metrics{ 'ROK_' . $cat } / $metrics{ 'RULES_' . $cat };
}

print "\nDisplaying unknown rules...\n";
foreach my $rule (keys %unknown_rules) {
    print "* " , $rule, " violated ", $unknown_rules{ $rule }, " times.\n";
}

# Write to a file
my $out_name = $file_xml;
$out_name =~ s/.xml$/.json/;
$out_name = basename( $out_name );

Dumper %metrics;

my $json_out;
$json_out = "{\n";
$json_out .= "    \"name\": \"Project metrics\",\n";
$json_out .= "    \"children\": [\n";
foreach my $metric (keys %metrics) {
    print "Working on $metric: $metrics{$metric}.\n";
    my $tmp_m = "        {\n";
    $tmp_m   .= "            \"name\": \"";
    $tmp_m   .= $metric;
    $tmp_m   .= "\",\n";
    $tmp_m   .= "            \"value\": \"$metrics{$metric}\"\n";
    $tmp_m   .= "        }";
    $json_out = join( ", \n", $json_out, $tmp_m);
}
$json_out .= "    ]\n";
$json_out .= "}\n";


open( FHOUT, ">$out_name" ) or die "Could not open $out_name.\n";
print FHOUT $json_out;
close FHOUT;

print "\n\n";
