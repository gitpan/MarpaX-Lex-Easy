package MarpaX::Lex::Easy;

# ABSTRACT: A simple, foolproof, scanner/driver for Marpa
our $AUTHORITY = 'cpan:ARODLAND'; # AUTHORITY
our $VERSION = '0.0000001'; # TRIAL VERSION

use Moo;
use MooX::Types::MooseLike::Base 0.16 qw(:all);
use Data::Dumper;

has 'tokens' => (
  is => 'ro',
  isa => HashRef,
  required => 1,
);

has 'recognizer' => (
  is => 'ro',
  isa => InstanceOf['Marpa::R2::Recognizer'],
  required => 1,
);

has 'automatic_whitespace' => (
  is => 'ro',
  isa => Int,
  default => sub { 0 },
);

has 'whitespace_pattern' => (
  is => 'ro',
  isa => RegexpRef,
);

has 'input' => (
  is => 'rw',
  isa => Str,
);

has 'pos' => (
  is => 'rw',
  isa => Int,
);

sub lex {
  my $self = shift;
  my ($input, $pos, @expected) = @_;

  my @matches;
  my $whitespace_consumed = 0;

  if ($self->automatic_whitespace) {
    pos($input) = $pos;
    if ($input =~ $self->whitespace_pattern) {
      $whitespace_consumed = $+[0] - $-[0];
      $pos += $whitespace_consumed;
    }
  }

  my $tokens = $self->tokens;

  TOKEN: for my $token_name (@expected) {
    my $token = $tokens->{$token_name};
    die "Unknown token $token_name" unless defined $token;
    next if $token eq 'passthrough';
    my $rule = $token->[0];

    pos($input) = $pos;
    next TOKEN unless $input =~ $rule;

    my $matched_len = $+[0] - $-[0];
    my $matched_value = undef;

    if (defined( my $val = $token->[1] )) {
      if (ref $val eq 'CODE') {
        eval {
          $matched_value = $val->();
          1;
        } || do {
          next TOKEN;
        };
      } else {
        $matched_value = $val;
      }
    } elsif ($#- > 0) { # Captured a value
      $matched_value = $1;
    }

    push @matches, [ $token_name, \$matched_value, $matched_len + $whitespace_consumed ];
  }
  return @matches;
}

sub one_earleme {
  my $self = shift;
  my $rec = $self->recognizer;
  my $input = $self->input;
  my $pos = $self->pos;

  my $expected_tokens = $rec->terminals_expected;

  my @matching_tokens;

  if (@$expected_tokens) {
    @matching_tokens = $self->lex($input, $pos, @$expected_tokens);
    $rec->alternative( @$_ ) for @matching_tokens;
  }

  my $ok = eval {
    $rec->earleme_complete;
    1;
  };

  if (@$expected_tokens && !$ok) {
    my $err = $@;
    die "Parse error, expecting [@$expected_tokens], got ", Dumper(\@matching_tokens),
      "(error $err at $pos, ", Data::Dumper::qquote(substr($input, $pos, 10)), ")\n";
  }
}

sub finish_parse {
  my $self = shift;
  $self->recognizer->end_input;
  my $ret = $self->recognizer->value;
  if (defined $ret) {
    return $$ret;
  } else {
    my $expected = $self->recognizer->terminals_expected;
    die "Parse error at EOF, expecting [@$expected]";
  }
}

sub parse {
  my $self = shift;
  my $length = length $self->input;
  while ($self->pos < $length) {
    $self->one_earleme;
    $self->pos($self->pos + 1);
  }
  return $self->finish_parse;
}

sub read_input {
  my $self = shift;
  my ($input) = @_;
  $self->input($input);
  $self->pos(0);
}

sub read_and_parse {
  my $self = shift;
  $self->read_input(@_);
  return $self->parse;
}

1;


__END__
=pod

=head1 NAME

MarpaX::Lex::Easy - A simple, foolproof, scanner/driver for Marpa

=head1 VERSION

version 0.0000001

=head1 AUTHOR

Andrew Rodland <arodland@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Andrew Rodland.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

