package GBV::PICASelector;
use v5.20;

use PICA::Data qw(pica_value pica_values pica_path pica_fields pica_subfields);

sub new {
    my ( $class, $value ) = @_;

    my $self = bless { value => $value }, $class;

    # TODO: support x-tags

    my ( $field, $sf ) = $value =~ /^([^[\$" ]+)\s*([\$"].*)$/;

    if ( $sf =~ /^(\$.\s*)+$/ ) {    # $a $b => $ab
        $self->{path} = pica_path( "$field\$" . ( $sf =~ s/\$|\s//gr ) );
    }
    elsif ( $sf =~ /^"([^"]*)"$/ ) {
        $self->{field}    = pica_path($field);
        $self->{template} = $1;
    }
    else {
        $self->{path} = pica_path("$field$sf");
    }

    return $self;
}

sub select_fields {
    my ( $self, $record ) = @_;
    my $field = $self->{field} or return;
    return grep { $field->match_field($_) } @{ pica_fields($record) };
}

sub select_all {
    my ( $self, $record ) = @_;

    if ( $self->{path} ) {
        return pica_values( $record, $self->{path} );
    }
    else {
        my @fields = $self->select_fields($record);

        my $tpl = $self->{template};

        # FIXME: get first instead of last when sf is repeated?
        return map {
            my $sf = pica_subfields( [$_] );
            $tpl =~ s/\$(.)/$sf->{$1}/gpr;
        } @fields;
    }
}

sub select {
    my ( $self, $record ) = @_;
    if ( $self->{path} ) {
        return pica_value( $record, $self->{path} );
    }
    else {
        my ($first) = $self->select_all($record);
        return $first;
    }
}

sub TO_JSON {
    return "" . $_[0]->{value};
}

1;
