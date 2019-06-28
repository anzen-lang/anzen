import ArgParse

extension ArgumentParser {

  func parseCommandLine() -> ArgumentParser.ParseResult {
    do {
      return try parse(CommandLine.arguments)
    } catch .invalidArity(let argument, let provided) as ArgumentParserError {
      let arity = argument.arity.map({ "\($0)" }) ?? "1"
      crash("'\(argument.name)' expects \(arity) argument(s), got \(provided)")
    } catch {
      crash("\(error)")
    }
  }

}
