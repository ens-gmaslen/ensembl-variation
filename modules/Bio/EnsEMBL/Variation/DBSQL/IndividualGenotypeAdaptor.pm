#
# Ensembl module for Bio::EnsEMBL::Variation::DBSQL::IndividualGenotypeAdaptor
#
# Copyright (c) 2004 Ensembl
#
# You may distribute this module under the same terms as perl itself
#
#

=head1 NAME

Bio::EnsEMBL::Variation::DBSQL::IndividualGenotypeAdaptor

=head1 SYNOPSIS

  $db = Bio::EnsEMBL::Variation::DBSQL::DBAdaptor->new(...);

  $iga = $db->get_IndividualGenotypeAdaptor();
  $ia  = $db->get_IndividualAdaptor();

  # Get an IndividualGenotype by its internal identifier
  $igtype = $ia->fetch_by_dbID(145);

  # Get all individual genotypes for an individual
  $ind = $ia->fetch_by_dbID(1219);

  foreach $igtype (@{$iga->fetch_all_by_Individual($ind)}) {
    print $igtype->variation()->name(),  ' ',
          $igtype->allele1(), '/', $igtype->allele2(), "\n";
  }



=head1 DESCRIPTION

This adaptor provides database connectivity for IndividualGenotype objects.
IndividualGenotypes may be retrieved from the Ensembl variation database by
several means using this module.

=head1 AUTHOR - Graham McVicker

=head1 CONTACT

Post questions to the Ensembl development list ensembl-dev@ebi.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;

package Bio::EnsEMBL::Variation::DBSQL::IndividualGenotypeAdaptor;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

use Bio::EnsEMBL::Variation::IndividualGenotype;
use Data::Dumper;

our @ISA = ('Bio::EnsEMBL::DBSQL::BaseAdaptor');



=head2 fetch_by_dbID

  Arg [1]    : int $dbID
  Example    : $igtype = $igtype_adaptor->fetch_by_dbID(15767);
  Description: Retrieves an individual genotype via its unique internal
               identifier.  undef is returned if no such individual genotype
               exists.
  Returntype : Bio::EnsEMBL::Variation::Variation::IndividualGenotype or undef
  Exceptions : throw if no dbID argument is provided
  Caller     : general

=cut

sub fetch_by_dbID {
  my $self = shift;
  my $dbID = shift;

  my $sth = $self->prepare
    (q{SELECT variation_id, allele_1, allele_2,
              individual_id
       FROM   individual_genotype
       WHERE  individual_genotype_id = ?});

  $sth->execute($dbID);

  my $row = $sth->fetchrow_arrayref();
  $sth->finish();

  return undef if(!$row);

  my ($var_id, $allele1, $allele2, $ind_id) = @$row;

  my $va = $self->db()->get_VariationAdaptor();
  my $var = $va->fetch_by_dbID($var_id);

  my $ia = $self->db()->get_IndividualAdaptor();
  my $ind = $ia->fetch_by_dbID($ind_id);

  return Bio::EnsEMBL::Variation::IndividualGenotype->new
    (-dbID    => $dbID,
     -adaptor => $self,
     -allele1 => $allele1,
     -allele2 => $allele2,
     -variation => $var,
     -individual => $ind);
}



=head2 fetch_all_by_Individual

  Arg [1]    : Bio::EnsEMBL::Variation::Individual
  Example    : $ind = $ind_adaptor->fetch_by_dbID(1345);
               @gtys = $igty_adaptor->fetch_all_by_Individual($ind);
  Description: Retrieves all genotypes which are stored for a specified
               individual.
  Returntype : Bio::EnsEMBL::Variation::IndividualGenotype
  Exceptions : throw on incorrect argument
  Caller     : general

=cut

sub fetch_all_by_Individual {
  my $self = shift;
  my $ind = shift;

  if(!ref($ind) || !$ind->isa('Bio::EnsEMBL::Variation::Individual')) {
    throw('Bio::EnsEMBL::Variation::Individual argument expected');
  }

  if(!defined($ind->dbID())) {
    warning("Cannot retrieve genotypes for individual without set dbID");
    return [];
  }

  my $sth = $self->prepare
    (q{SELECT individual_genotype_id, variation_id, allele_1, allele_2
       FROM   individual_genotype
       WHERE  individual_id = ?});

  $sth->execute($ind->dbID());

  my %variation_hash;

  my ($igtype_id, $var_id, $allele1, $allele2);
  $sth->bind_columns(\$igtype_id, \$var_id, \$allele1, \$allele2);

  my @results;

  while($sth->fetch()) {
    my $igtype = Bio::EnsEMBL::Variation::IndividualGenotype->new
      (-dbID => $igtype_id,
       -adaptor => $self,
       -allele1 => $allele1,
       -allele2 => $allele2,
       -individual => $ind);
    $variation_hash{$var_id} ||= [];
    push @{$variation_hash{$var_id}}, $igtype;
    push @results, $igtype;
  }

  # get all variations in one query (faster)
  # and add to already created genotypes
  my @var_ids = keys %variation_hash;
  my $va = $self->db()->get_VariationAdaptor();
  my $vars = $va->fetch_all_by_dbID_list(\@var_ids);

  foreach my $v (@$vars) {
    foreach my $igty (@{$variation_hash{$v->dbID()}}) {
      $igty->variation($v);
    }
  }

  return \@results;
}



=head2 fetch_all_by_Variation

  Arg [1]    : Bio::EnsEMBL::Variation $variation
  Example    : my $var = $variation_adaptor->fetch_by_name( "rs1121" )
               $igtypes = $igtype_adaptor->fetch_all_by_Variation( $var )
  Description: Retrieves a list of individual genotypes for the given Variation.
               If none are available an empty listref is returned.
  Returntype : listref Bio::EnsEMBL::Variation::IndividualGenotype 
  Exceptions : none
  Caller     : general

=cut


sub fetch_all_by_Variation {
    my $self = shift;
    my $variation = shift;

    if(!ref($variation) || !$variation->isa('Bio::EnsEMBL::Variation::Variation')) {
	throw('Bio::EnsEMBL::Variation::Variation argument expected');
    }

    if(!defined($variation->dbID())) {
	warning("Cannot retrieve genotypes for variation without set dbID");
	return [];
    }

    my $sth = $self->prepare
	(q{SELECT individual_genotype_id, individual_id, allele_1, allele_2
	       FROM   individual_genotype
	       WHERE  variation_id = ?});
    
    $sth->execute($variation->dbID());
    
    my ($igty_id, $ind_id, $allele1, $allele2);
    $sth->bind_columns(\$igty_id, \$ind_id, \$allele1, \$allele2);
    
    my @results;
    my %individual_hash;
    while($sth->fetch()) {
	my $igty = Bio::EnsEMBL::Variation::IndividualGenotype->new
	    (-dbID => $igty_id,
	     -variation => $variation,
	     -adaptor => $self,
	     -allele1 => $allele1,
	     -allele2 => $allele2,
	     );
	$individual_hash{$ind_id} ||= [];
	push @{$individual_hash{$ind_id}}, $igty;
	push @results, $igty;
    }

    # get all individual in one query (faster)
    # and add to already created genotypes
    my @ind_ids = keys %individual_hash;
    my $ia = $self->db()->get_IndividualAdaptor();
    my $inds = $ia->fetch_all_by_dbID_list(\@ind_ids);
    
    foreach my $i (@$inds) {
	foreach my $igty (@{$individual_hash{$i->dbID()}}) {
	    $igty->individual($i);
	}
    }
    return \@results;   

}




1;
