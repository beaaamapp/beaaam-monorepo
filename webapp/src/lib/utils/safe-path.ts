const PROTOCOL_PATTERN = /^(?:[a-z0-9]+:)/;


export default function (input: string) {
  const hasProtocolPattern = PROTOCOL_PATTERN.test(input);
  const hasDoubleSlash = input.startsWith('//');

  return !hasProtocolPattern && !hasDoubleSlash;
}
