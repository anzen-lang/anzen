import Foundation

func printStackTrace() {
    for symbol in Thread.callStackSymbols.reversed() {
        print(symbol)
    }
}
