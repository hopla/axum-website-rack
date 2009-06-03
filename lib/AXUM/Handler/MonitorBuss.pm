
package AXUM::Handler::MonitorBuss;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{monitorbuss} => \&monitorbuss,
  qr{ajax/monitorbuss} => \&ajax,
);


my @busses = map sprintf('buss_%d_%d', $_*2-1, $_*2), 1..16;


# arguments: field name, db return object
sub _col {
  my($n, $d) = @_;
  my $v = $d->{$n};

  if($n eq 'label') {
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $jsval =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_text("monitorbuss", %d, "label", "%s", this)', $d->{number}, $jsval), $v;
  }
  if($n eq 'interlock') {
    a href => '#', onclick => sprintf('return conf_set("monitorbuss", %d, "interlock", "%s", this)', $d->{number}, $v?0:1),
      !$v ? (class => 'off', 'no') : 'yes';
  }
  if($n =~ /buss_/) {
    a href => '#', onclick => sprintf('return conf_set("monitorbuss", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
      !$v ? (class => 'off', 'n') : 'y';
  }
  if($n eq 'dim_level') {
    a href => '#', onclick => sprintf('return conf_level("monitorbuss", %d, "dim_level", %f, this)', $d->{number}, $v),
      $v == 0 ? (class => 'off') : (), sprintf '%.1f dB', $v;
  }
  if($n eq 'default_selection') {
    i '-';
  }
}


sub monitorbuss {
  my $self = shift;

  my $busses = $self->dbAll('SELECT number, label FROM buss_config ORDER BY number');
  my $mb = $self->dbAll('SELECT number, label, interlock, default_selection, dim_level, !s
    FROM monitor_buss_config ORDER BY number', join ', ', @busses);

  $self->htmlHeader(page => 'monitorbuss');
  table;
   Tr; th colspan => 21, 'Monitor buss configuration'; end;
   Tr;
    th colspan => 3, '';
    th rowspan => 2, "Default\nselection";
    th colspan => 17, 'Automatic switching';
   end;
   Tr;
    th 'Nr.';
    th 'Label';
    th 'Interlock';
    th id => "exp_$_->{number}", abbr => $_->{label}, $_->{number}%10
      for (@$busses);
    th 'Dim level';
   end;

   for my $m (@$mb) {
     Tr;
      th $m->{number};
      td; _col 'label', $m; end;
      td; _col 'interlock', $m; end;
      td; _col 'default_selection', $m; end;
      for (@$busses) {
        td class => "exp_$_->{number}";
         _col $busses[$_->{number}-1], $m;
        end;
      }
      td; _col 'dim_level', $m; end;
     end;
   }
  end;
  $self->htmlFooter;
}


sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    { name => 'label', required => 0, maxlength => 32, minlength => 1 },
    { name => 'interlock', required => 0, enum => [0,1] },
    { name => 'default_selection', required => 0, template => 'int' },
    { name => 'dim_level', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    map +{ name => $_, required => 0, enum => [0,1] }, @busses
  );
  return 404 if $f->{_err};

  my %set;
  defined $f->{$_} and ($set{"$_ = ?"} = $f->{$_})
    for(qw|label interlock default_selection dim_level|, @busses);

  $self->dbExec('UPDATE monitor_buss_config !H WHERE number = ?', \%set, $f->{item}) if keys %set;
  _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} };
}


1;

