#!/usr/bin/env perl

use Getopt::Long;
use Bio::EnsEMBL::Variation::Utils::Constants qw(%OVERLAP_CONSEQUENCES);
use Bio::EnsEMBL::Registry;

my $config = {};

GetOptions(
    $config,
	'host|h=s',
	'user|u=s',
	'password|p=s',
	'port|P=i',
	'version|v=i',
) or die "ERROR: Could not parse command line options\n";

$config->{host} ||= 'ens-staging';
$config->{user} ||= 'ensro';
$config->{port} ||= 3306;

my $reg = 'Bio::EnsEMBL::Registry';
$reg->load_registry_from_db(-host => $config->{host}, -user => $config->{user}, -port => $config->{port}, -db_version => $config->{version});

my $oa = $reg->get_adaptor( 'Multi', 'Ontology', 'OntologyTerm' );

die "ERROR: Could not get ontology term adaptor\n" unless defined($oa);

my %term_list = ();

foreach my $con(values %OVERLAP_CONSEQUENCES) {
	my $obj = $oa->fetch_by_accession($con->SO_accession);
	
	get_parents($obj, \%term_list);
}

print "$_\n" for sort keys %term_list;

sub get_parents {
	my $obj = shift;
	my $term_list = shift;
	
	get_parents($_, $term_list) for @{$obj->parents};
	
	$term_list->{$obj->name} = 1;
}