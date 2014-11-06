#!/usr/bin/env perl
use Test::Mojo;
use Test::More;
use Mojolicious::Lite;
use strict;
use warnings;

# Todo: test page_start, page_end, page = {page}

$|++;

use lib '../lib';

my $t = Test::Mojo->new;

my $app = $t->app;

my $c = Mojolicious::Controller->new;
$c->app($app);

$app->plugin('TagHelpers::Pagination');

# diag $app->pagination(6, 18, '#{page}' => {
#   separator => " ",
#   current => '[{current}]'
# });
# L<&lt;|#> L<1|#> ... L<5|#> B<6> L<7|#> ... L<18|#> L<&gt;|#>
# <center><a href="#5" rel="prev">&lt;</a> <a href="#1">1</a> ... <a href="#5">5</a> <a rel="self">[6]</a> <a href="#7">7</a> ... <a href="#18">18</a> <a href="#7" rel="next">&gt;</a></center>



my $string = $c->pagination( 4, 15, '#action={page}' => {
  prev => '&lt;',
  next => '&gt;',
  separator => '&nbsp;',
  ellipsis => '...'
});

like($string, qr/href="#action=3" rel="prev">&lt;/, 'Prev is correct');
like($string, qr/href="#action=5" rel="next">&gt;/, 'Next is correct');
like($string, qr/a rel="self">\[/, 'Self is correct');


like($string, qr/^\<a href="#action=3"[^>]*>\&lt;<\/a>\&nbsp;/, 'String begin');
like($string, qr/\<a href="#action=5"[^>]*>\&gt;<\/a>$/, 'String end');
like($string,
     qr/<a href="#action=5"[^>]*>5<\/a>\&nbsp;\.\.\.\&nbsp;<a href="#action=15">15<\/a>/,
     'String ellipsis');
like($string, qr/\[4\]/, 'Current');


$string = $c->pagination( 4, 15, '/page-{page}?page={page}');

like($string, qr/^<a href="\/page-3\?page=3" rel="prev">\&lt;<\/a>/, 'New template');
my $url = Mojo::URL->new('http://sojolicio.us:3000/pages');
$url->query({ page => 'offset-{page}'});

$string = $c->pagination( 4, 15, $url);

like($string,
     qr/^<a href="http:\/\/sojolicio\.us:3000\/pages\?page=offset-3" rel="prev">\&lt;<\/a>/,
     'Pagination with Mojo::URL');

$string = $c->pagination( 2, 3 );
unlike($string, qr/\.\.\./, 'No ellipsis');

$string = $c->pagination(1,1);
is($string, '<a rel="prev">&lt;</a>&nbsp;<a rel="self">[1]</a>&nbsp;<a rel="next">&gt;</a>', 'Pagination 1/1');

$string = $c->pagination(1,2);
is($string, '<a rel="prev">&lt;</a>&nbsp;<a rel="self">[1]</a>&nbsp;<a href="2">2</a>'.
     '&nbsp;<a href="2" rel="next">&gt;</a>',
   'Pagination 1/2');


$string = $c->pagination(2,2);
is($string, '<a href="1" rel="prev">&lt;</a>&nbsp;<a href="1">1</a>'.
     '&nbsp;<a rel="self">[2]</a>&nbsp;<a rel="next">&gt;</a>',
   'Pagination 2/2');

$string = $c->pagination(1,3);
is($string, '<a rel="prev">&lt;</a>&nbsp;<a rel="self">[1]</a>&nbsp;<a href="2">2</a>&nbsp;'.
     '<a href="3">3</a>&nbsp;<a href="2" rel="next">&gt;</a>',
   'Pagination 1/3');

$string = $c->pagination(2,3);
is($string, '<a href="1" rel="prev">&lt;</a>&nbsp;<a href="1">1</a>&nbsp;'.
     '<a rel="self">[2]</a>&nbsp;<a href="3">3</a>&nbsp;<a href="3" rel="next">&gt;</a>',
   'Pagination 2/3');

$string = $c->pagination(3,3);
is($string, '<a href="2" rel="prev">&lt;</a>&nbsp;<a href="1">1</a>&nbsp;'.
     '<a href="2">2</a>&nbsp;<a rel="self">[3]</a>&nbsp;<a rel="next">&gt;</a>',
   'Pagination 3/3');

$string = $c->pagination(3,7);
is($string, '<a href="2" rel="prev">&lt;</a>&nbsp;<a href="1">1</a>&nbsp;'.
     '<a href="2">2</a>&nbsp;<a rel="self">[3]</a>&nbsp;<a href="4">4</a>&nbsp;'.
       '...&nbsp;<a href="7">7</a>&nbsp;<a href="4" rel="next">&gt;</a>',
   'Pagination 3/7');

$string = $c->pagination(0,8);
is($string, '<a rel="prev">&lt;</a>&nbsp;<a href="1">1</a>&nbsp;'.
     '<a href="2">2</a>&nbsp;<a href="3">3</a>&nbsp;'.
       '...&nbsp;<a href="8">8</a>&nbsp;<a href="1" rel="next">&gt;</a>',
   'Pagination 0/8');

$string = $c->pagination(0,0);
is($string, '', 'Pagination 0/0');

$string = $c->pagination(0,1);
is($string, '<a rel="prev">&lt;</a>&nbsp;<a href="1">1</a>&nbsp;<a href="1" rel="next">&gt;</a>',
   'Pagination 0/1');

$string = $c->pagination(0,2);
is($string, '<a rel="prev">&lt;</a>&nbsp;<a href="1">1</a>&nbsp;<a href="2">2</a>&nbsp;<a href="1" rel="next">&gt;</a>',
   'Pagination 0/2');

$string = $c->pagination(0,3);
is($string, '<a rel="prev">&lt;</a>&nbsp;<a href="1">1</a>&nbsp;<a href="2">2</a>&nbsp;<a href="3">3</a>&nbsp;<a href="1" rel="next">&gt;</a>',
   'Pagination 0/3');

$string = $c->pagination(0,4);
is($string, '<a rel="prev">&lt;</a>&nbsp;<a href="1">1</a>&nbsp;<a href="2">2</a>&nbsp;<a href="3">3</a>&nbsp;<a href="4">4</a>&nbsp;<a href="1" rel="next">&gt;</a>',
   'Pagination 0/4');

$string = $c->pagination( 4, 15, '#action={page}' => {
  separator => ' ',
  prev      => '***',
  next      => '+++',
  ellipsis  => '---',
  current   => '<strong>{current}</strong>'
});

like($string, qr/^<a href="#action=3" rel="prev">\*\*\*<\/a> /, 'String begin');

like($string, qr/<a href="#action=5" rel="next">\+\+\+<\/a>$/, 'String end');
like($string,
     qr/<a href="#action=5">5<\/a> --- <a href="#action=15">15<\/a>/,
     'String ellipsis');
like($string, qr/<strong>4<\/strong>/, 'Current');

$t = Test::Mojo->new;
$app = $t->app;
$c->app($app);

$app->plugin('TagHelpers::Pagination' =>
	       {
		 separator => ' ',
		 prev      => '***',
		 next      => '+++',
		 ellipsis  => '---',
		 current   => '<strong>{current}</strong>',
		 placeholder => 'startPage'
	       }
	   );

$string = $c->pagination( 4, 15, '#action={startPage}');

like($string, qr/^<a href="#action=3" rel="prev">\*\*\*<\/a> /, 'String begin');
like($string, qr/<a href="#action=5" rel="next">\+\+\+<\/a>$/, 'String end');
like($string,
     qr/<a href="#action=5">5<\/a> --- <a href="#action=15">15<\/a>/,
     'String ellipsis');
like($string, qr/<strong>4<\/strong>/, 'Current');

is($c->pagination(0,0, ''), '', 'No page');
is($c->pagination(0,1, ''), '<a rel="prev">***</a> <a href="1">1</a> <a href="1" rel="next">+++</a>', 'No current page');
is($c->pagination(1,0, ''), '', 'No page');
is($c->pagination(0,1), '<a rel="prev">***</a> <a href="1">1</a> <a href="1" rel="next">+++</a>', 'No current page');
is($c->pagination(0,1, undef), '<a rel="prev">***</a> <a href="1">1</a> <a href="1" rel="next">+++</a>', 'No current page');



done_testing;
__END__
