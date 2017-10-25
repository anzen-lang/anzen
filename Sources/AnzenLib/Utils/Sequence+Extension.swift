func *<S1: Sequence, S2: Sequence>(lhs: S1,rhs : S2)
    -> AnySequence<(S1.Iterator.Element, S2.Iterator.Element)>
{
    return AnySequence (
        lhs.lazy.flatMap { x in rhs.lazy.map { y in (x,y) }}
    )
}
