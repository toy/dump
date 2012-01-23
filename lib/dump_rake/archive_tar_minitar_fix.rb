class Archive::Tar::Minitar::Reader::EntryStream
  def getbyte
    return nil if @read >= @size
    ret = @io.getbyte
    @read += 1 if ret
    ret
  end
end
