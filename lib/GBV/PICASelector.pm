package GBV::PICASelector;
use v5.20;

use PICA::Data qw(pica_value);

sub new {
    my ( $class, $value ) = @_;

    # TODO: parse $value

    bless { value => $value }, $class;
}

sub select_all {
    my ( $self, $record ) = @_;
    return pica_values( $record, $self->{value} );
}

sub select_first {
    my ( $self, $record ) = @_;
    return pica_value( $record, $self->{value} );
}

sub TO_JSON {
    return "" . $_[0]->{value};
}

1;
