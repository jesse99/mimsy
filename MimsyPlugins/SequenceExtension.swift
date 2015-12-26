import Foundation

extension SequenceType
{
    @warn_unused_result
    public func countFiltered(@noescape includeElement: (Self.Generator.Element) throws -> Bool) rethrows -> Int
    {
        var count = 0
        
        var generator = self.generate()
        while (true)
        {
            if let element = generator.next()
            {
                if try includeElement(element)
                {
                    count += 1
                }
            }
            else
            {
                break
            }
        }
        
        return count
    }
}
