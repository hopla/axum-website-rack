
package AXUM::Handler::ModuleAssign;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{config/module/assign} => \&assign,
  qr{config/module/assign/generate} => \&generate,
  qr{ajax/config/module/assign} => \&ajax,
);


my @busses = map sprintf('buss_%d_%d_assignment', $_*2-1, $_*2), 1..16;


sub _col {
  my($n, $d) = @_;
  my $v = $d->{$n};

  if($n eq 'console') {
    a href => '#', onclick => sprintf('return conf_select("config/module/assign", %d, "%s", %d, this, "console_list")', $d->{number}, $n, $v),
      $v;
  }
  if($n =~ /assignment/) {
   a href => '#', onclick => sprintf('return conf_set("config/module/assign", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
     $v ? 'y' : (class => 'off', 'n');
  }
}


sub assign {
  my $self = shift;

  my $p = $self->formValidate({name => 'p', required => 0, default => 1, enum => [1..4]});
  return 404 if $p->{_err};
  $p = $p->{p};

  my $bus = $self->dbAll('SELECT number, label FROM buss_config ORDER BY number');
  my $mod = $self->dbAll('SELECT number, console, !s FROM module_config WHERE number >= ? AND number <= ? ORDER BY number',
    join(', ', @busses), $p*32-31, $p*32);
  my $dspcount = $self->dbRow('SELECT dsp_count() AS cnt')->{cnt};

  $self->htmlHeader(title => 'Module assignment', area => 'config', page => 'moduleassign');
  div id => 'console_list', class => 'hidden';
    Select;
      option value => $_, 'Console '.($_) for (1..4);
    end;
  end;
  table;
   Tr;
    th colspan => 33;
     p class => 'navigate';
      txt 'Page: ';
      a href => "?p=$_", $p == $_ ? (class => 'sel') : (), $_
        for (1..4);
     end;
     txt 'Module assignment';
    end;
   end;
   Tr $p > $dspcount ? (class => 'inactive') : ();
    th '';
    th style => 'padding: 1px 0; width: 20px', $_->{number}
      for (@$mod);
   end;
   Tr $p > $dspcount ? (class => 'inactive') : ();
    th 'Console';
    for (@$mod) {
      td;
       _col 'console', $_;
      end;
    }
   end;
   Tr class => 'empty'; th colspan => 33; a href=> '/config/module/assign/generate', 'generate'; txt ' assignment from console information (takes some seconds!)'; end; end;
   for my $b (@$bus) {
     Tr $p > $dspcount ? (class => 'inactive') : ();
      th $b->{label};
      for (@$mod) {
        td;
         _col $busses[$b->{number}-1], $_;
        end;
      }
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
    { name => 'console', required => 0, enum => [1,2,3,4] },
    map +{ name => $_, required => 0, enum => [0,1] }, @busses
  );
  return 404 if $f->{_err};

  my %set = map +("$_ = ?", $f->{$_}), grep defined $f->{$_}, @busses, 'console';
  $self->dbExec('UPDATE module_config !H WHERE number = ?', \%set, $f->{item});
  _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} };
}

sub generate {
  my $self = shift;
  my $buss_asgn = $self->dbAll('SELECT b.number-1 AS buss_number, m.number AS module_number, b.console FROM buss_config b LEFT JOIN module_config m ON b.console = m.console ORDER BY m.number, b.number');

  my %set = map +("$_ = ?", 'false'), @busses;
  $self->dbExec('UPDATE module_config !H', \%set);

  for (1..128) {
    my $mod_busses = $self->dbAll('SELECT b.number-1 AS buss_number, m.number AS module_number, b.console FROM buss_config b LEFT JOIN module_config m ON b.console = m.console WHERE m.number = ? ORDER BY b.number', $_);

    my %set = map +("$busses[$_->{buss_number}] = ?", 'true'), @$mod_busses;
    $self->dbExec('UPDATE module_config !H WHERE number = ?', \%set, $_) if keys %set;
  }

  $self->resRedirect('/config/module/assign', 'temp');
}

1;

