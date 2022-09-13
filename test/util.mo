import O "../src/observable";
import Debug "mo:base/Debug";

module {
    public func runTest<X>( obs: O.Obs<X>, toText: (X) -> Text, okText : Text ) {
    var te : Text = "";
    ignore obs.subscribe({
        next = func (v) {
            te := te # " " # toText(v);
        };
        complete = func () {
            te := te # " | ";
            if (te == okText) {te := te # "- OK ";} else te := te # "- ERROR ";
            Debug.print(te);
        }
    });
    };
}