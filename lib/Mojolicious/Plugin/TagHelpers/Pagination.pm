package Mojolicious::Plugin::TagHelpers::Pagination;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Scalar::Util 'blessed';
use POSIX 'ceil';

our $VERSION = 0.01;

our @value_list =
  qw/prev
     next
     current_start
     current_end
     page_start
     page_end
     separator
     ellipsis
     placeholder/;

# Register plugin
sub register {
  my ($plugin, $mojo, $param) = @_;

  $param ||= {};

  # Load parameter from Config file
  if (my $config_param = $mojo->config('TagHelpers-Pagination')) {
    $param = { %$config_param, %$param };
  };

  foreach (@value_list) {
    $plugin->{$_} = $param->{$_} if defined $param->{$_};
  };

  # Set 'current_start' and 'current_end' symbols,
  # if 'current' template is available.
  # Same for 'page'.
  foreach (qw/page current/) {
    if (defined $param->{$_}) {
      @{$plugin}{$_ . '_start', $_ . '_end'} = split("{$_}", $param->{$_});
      $plugin->{$_ . '_end'} ||= '';
    };
  };

  # Default current start and current end symbols
  for ($plugin) {
    $_->{current_start} //= '[';
    $_->{current_end}   //= ']';
    $_->{page_start}    //= '';
    $_->{page_end}      //= '';
    $_->{prev}          //= '&lt;';
    $_->{next}          //= '&gt;';
    $_->{separator}     //= '&nbsp;';
    $_->{ellipsis}      //= '...';
    $_->{placeholder}   //= 'page';
  };

  # Establish pagination helper
  $mojo->helper(
    pagination => sub {
      shift; # Controller
      return b( $plugin->pagination( @_ ) );
    });
};


# Pagination helper
sub pagination {
  my $self = shift;

  # $_[0] = current page
  # $_[1] = page count
  # $_[2] = template or Mojo::URL

  return '' unless $_[0] || $_[1];

  # No valid count given
  local $_[1] = !$_[1] ? 1 : ceil($_[1]);

  # New parameter hash
  my %values =
    map { $_ => $self->{$_} } @value_list;

  # Overwrite plugin defaults
  if ($_[3] && ref $_[3] eq 'HASH') {
    my $overwrite = $_[3];
    foreach (@value_list) {
      $values{$_}  = $overwrite->{$_} if defined $overwrite->{$_};
    };

    foreach (qw/page current/) {
      if (defined $overwrite->{$_}) {
	@values{$_ . '_start', $_ . '_end'} = split("{$_}", $overwrite->{$_});
	$values{$_ . '_end'} ||= '';
      };
    };
  };

  # Establish string variables
  my ($p, $n, $cs, $ce, $ps, $pe, $s, $el, $ph) = @values{@value_list};
  # prev next current_start current_end
  # page_start page_end separator ellipsis placeholder

  # Template
  my $t = $_[2];
  if (blessed $t && blessed $t eq 'Mojo::URL') {
    $t = $t->to_string;
    $t =~ s/\%7[bB]$ph\%7[dD]/{$ph}/g;
  };


  my $sub = sublink_gen($t,$ps,$pe,$ph);

  # Pagination string
  my $e;
  my $counter = 1;

  if ($_[1] >= 7){

    # < [1] #2 #3
    if ($_[0] == 1){
      $e .= $sub->(undef, [$p, 'prev']) . $s .
	    $sub->(undef, [$cs . 1  . $ce, 'self']) . $s .
	    $sub->('2') . $s .
	    $sub->('3') . $s;
    }

    # < #1 #2 #3
    elsif (!$_[0]) {
      $e .= $sub->(undef, [$p, 'prev']) . $s;
      $e .= $sub->($_) . $s foreach (1 .. 3);
    }

    # #< #1
    else {
      $e .= $sub->(($_[0] - 1), [$p, 'prev']) . $s .
            $sub->('1') . $s;
    };

    # [2] #3
    if ($_[0] == 2){
      $e .= $sub->(undef, [$cs . 2 . $ce, 'self']) . $s .
	    $sub->('3') . $s;
    }

    # ...
    elsif ($_[0] > 3){
      $e .= $el . $s;
    };

    # #x-1 [x] #x+1
    if (($_[0] >= 3) && ($_[0] <= ($_[1] - 2))){
      $e .= $sub->($_[0] - 1) . $s .
	    $sub->(undef, [$cs .$_[0] . $ce, 'self']) . $s .
	    $sub->($_[0] + 1) . $s;
    };

    # ...
    if ($_[0] < ($_[1] - 2)){
      $e .= $el . $s;
    };

    # number is prefinal
    if ($_[0] == ($_[1] - 1)){
      $e .= $sub->($_[1] - 2) . $s .
	    $sub->(undef, [$cs . $_[0] . $ce, 'self']) . $s;
    };

    # Number is final
    if ($_[0] == $_[1]){
      $e .= $sub->($_[1] - 1) . $s .
            $sub->(undef, [$cs . $_[1] . $ce, 'self']) . $s .
	    $sub->(undef, [$n, 'next']);
    }

    # Number is anywhere in between
    else {
      $e .= $sub->($_[1]) . $s .
            $sub->(($_[0] + 1), [$n,'next']);
    };
  }

  # Counter < 7
  else {

    # Previous
    if ($_[0] > 1){
      $e .= $sub->(($_[0] - 1), [$p, 'prev']) . $s;
    } else {
      $e .= $sub->(undef, [$p, 'prev']) . $s;
    };

    # All numbers in between
    while ($counter <= $_[1]){
      if ($_[0] != $counter) {
        $e .= $sub->($counter) . $s;
      }

      # Current
      else {
        $e .= $sub->(undef, [$cs . $counter . $ce, 'self']) . $s;
      };

      $counter++;
    };

    # Next
    if ($_[0] != $_[1]){
      $e .= $sub->(($_[0] + 1), [$n, 'next']);
    }

    else {
      $e .= $sub->(undef, [$n, 'next']);
    };
  };

  # Pagination string
  $e;
};

# Sublink function generator
sub sublink_gen {
  my ($url, $ps, $pe, $ph) = @_;

  my $s = 'sub {';
  # $_[0] = number
  # $_[1] = number_shown

  # Url is template
  if ($url) {
    $s .= 'my $url=' . b($url)->quote . ';';
    $s .= 'if($_[0]){$url=~s/\{' . $ph . '\}/$_[0]/g}else{$url=undef};';
  }

  # No template given
  else {
    $s .= 'my $url = $_[0];';
  };

  $s .= 'my$n=$_[1]||' . b($ps)->quote . '.$_[0].' . b($pe)->quote . ';';
  $s .= q{my $rel='';};
  $s .= q{if(ref $n){$rel=' rel="'.$n->[1].'"';$n=$n->[0]};};
  $s .= q!if($url){$url=~s/&/&amp;/g;!;
  $s .= q{$url=~s/</&lt;/g;};
  $s .= q{$url=~s/>/&gt;/g;};
  $s .= q{$url=~s/"/&quot;/g;};
  $s .= q!$url=~s/'/&#39;/g;};!;

  # Create sublink
  $s .= q{return '<a'.($url?' href="'.$url.'"':'').$rel.'>' . $n . '</a>';};
  $s .= '}';

  my $x = eval($s);

  warn $@ if $@;

  $x;
};


1;


__END__

=pod

=head1 NAME

Mojolicious::Plugin::TagHelpers::Pagination - Pagination Helper for Mojolicious


=head1 SYNOPSIS

  # Mojolicious
  $app->plugin('TagHelpers::Pagination' => {
    separator => ' ',
    current => '<strong>{current}</strong>'
  });

  # Mojolicious::Lite
  plugin 'TagHelpers::Pagination' => {
    separator => ' ',
    current   =>  '<strong>{current}</strong>'
  };

  # In Templates
  %= pagination(2, 4, '?page={page}' => { separator => "\n" })
  # <a href="?page=1" rel="prev">&lt;</a>
  # <a href="?page=1">1</a>
  # <a rel="self"><strong>2</strong></a>
  # <a href="?page=3">3</a>
  # <a href="?page=4">4</a>
  # <a href="?page=3" rel="next">&gt;</a>

=head1 DESCRIPTION

L<Mojolicious::Plugin::TagHelpers::Pagination> helps you to create
pagination elements in your templates, like this:

L<E<lt>|/#> L<1|/#> ... L<5|/#> B<[6]> L<7|/#> ... L<18|/#> L<E<gt>|/#>

=head1 METHODS

L<Mojolicious::Plugin::TagHelpers::Pagination> inherits all methods from
L<Mojolicious::Plugin> and implements the following new one.


=head2 register

  # Mojolicious
  $app->plugin('TagHelpers::Pagination' => {
    separator => ' ',
    current => '<strong>{current}</strong>'
  });

  # Or in your config file
  {
    'TagHelpers-Pagination' => {
      separator => ' ',
      current => '<strong>{current}</strong>'
    }
  }

Called when registering the plugin.

All L<parameters|/PARAMETERS> can be set either on registration or
as part of the configuration file with the key C<TagHelpers-Pagination>.


=head1 HELPERS

=head2 pagination

  # In Templates:
  %= pagination(4, 6 => '/page-{page}.html');
  % my $url = Mojo::URL->new->query({ page => '{page}'});
  %= pagination(4, 6 => $url);
  %= pagination(4, 6 => '/page/{page}.html', { current => '<b>{current}</b>' });

Generates a pagination string.
Expects at least two numeric values: the current page number and
the total count of pages.
Additionally it accepts a link pattern and a hash reference
with parameters overwriting the default plugin parameters for
pagination.
The link pattern can be a string using a placeholder in curly brackets
(defaults to C<page>) for the page number it should link to.
It's also possible to give a
L<Mojo::URL> object containing the placeholder.
The placeholder can be used multiple times.


=head1 PARAMETERS

For the layout of the pagination string, the plugin accepts the
following parameters, that are able to overwrite the default
layout elements. These parameters can again be overwritten in
the pagination helper.

=over 2

=item current

Pattern for current page number. The C<{current}> is a
placeholder for the current number.
Defaults to C<[{current}]>.
Instead of a pattern, both sides of the current number
can be defined with C<current_start> and C<current_end>.


=item ellipsis

Placeholder symbol for hidden pages. Defaults to C<...>.


=item next

Symbol for next pages. Defaults to C<&gt;>.


=item page

Pattern for page number. The C<{page}> is a
placeholder for the page number.
Defaults to C<{page}>.
Instead of a pattern, both sides of the page number
can be defined with C<page_start> and C<page_end>.


=item placeholder

String representing the placeholder for the page number in the URL
pattern. Defaults to C<page>.


=item prev

Symbol for previous pages. Defaults to C<&lt;>.


=item separator

Symbol for the separation of pagination elements.
Defaults to C<&nbsp;>.

=back


=head1 DEPENDENCIES

L<Mojolicious>.


=head1 AVAILABILITY

  https://github.com/Akron/Mojolicious-Plugin-TagHelpers-Pagination


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2014, L<Nils Diewald|http://nils-diewald.de/>.

This program is free software, you can redistribute it
and/or modify it under the terms of the Artistic License version 2.0.

=cut
