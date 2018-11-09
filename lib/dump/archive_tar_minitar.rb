require 'archive/tar/minitar'

Archive::Tar::Minitar::Reader::EntryStream.class_eval do
  def getbyte
    return nil if @read >= @size

    ret = @io.getbyte
    @read += 1 if ret
    ret
  end
end
