# RxMo - Reactive programming with Motoko

For Motoko language @ Internet Computer

Not a full RxMo implementation. Work in progress.

Currently has Observable, Subject, pipe, of, map, first, concatAll, mergeMap

Missing: 
- Unsubscribe
- Async
- Many operators
- Schedulers

## Playground example 
https://m7sm4-2iaaa-aaaab-qabra-cai.raw.ic0.app/?tag=3129927563

## Example
```mo
pipe2(
    of<Text>(["A","B","C"]),
    mergeMap<Text,Text>( func(x) { 
        pipe2(
            of<Nat>([1,2,3,4,5,6]),
            map<Nat, Text>( func (i) {
                x # debug_show(i);
            })
        );
    }, 1)
).subscribe( {
    next = func (v) {
        Debug.print(v);
    };
    complete = func () {
        Debug.print("complete");
    }
});
```

Outputs:

```
A1 A2 A3 A4 A5 A6 B1 B2 B3 B4 B5 B6 C1 C2 C3 C4 C5 C6
```

## Run tests
./helpers/test.sh

## Monitor tests
./helpers/monitor.sh

