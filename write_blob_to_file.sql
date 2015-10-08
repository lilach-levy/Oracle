---------------------------------------------------------------------------
-- write_blob_to_file
-- Note : This procedure works on oracle 10g and above ...
---------------------------------------------------------------------------
create or replace procedure write_blob_to_file ( p_blob           in     blob,
                                                 p_directory_name in     varchar2,
                                                 p_file_name      in     varchar2,
                                                 p_file_type      in     varchar2,
                                                 p_error          in out varchar2)
Is
  l_file_name        varchar2(256);
  l_file_type        varchar2(256);
  l_blob_length      integer;
  l_out_file         utl_file.file_type;
  l_buffer           raw(32767);
  l_chunk_size       binary_integer := 32767;
  l_blob_position    integer := 1;

  l_error            varchar2(500);
  l_exc              exception;
Begin
  -- Retrieve the SIZE of the BLOB
  l_blob_length := dbms_lob.getlength(p_blob);

  -- Open file for write
  -- The 'wb' parameter means "write in byte mode"
  l_out_file := utl_file.fopen (location     => p_directory_name,
                                filename     => p_file_name,
                                open_mode    => 'wb',
                                max_linesize => l_chunk_size);

  -- Write the BLOB to the File in chunks
  while l_blob_position <= l_blob_length loop
    if l_blob_position + l_chunk_size - 1 > l_blob_length then
      l_chunk_size := l_blob_length - l_blob_position + 1;
    end if;

    dbms_lob.read(lob_loc => p_blob,
                  amount  => l_chunk_size,
                  offset  => l_blob_position,
                  buffer  => l_buffer);

    utl_file.put_raw(file      => l_out_file,
                     buffer    => l_buffer,
                     autoflush => true);

    l_blob_position := l_blob_position + l_chunk_size;
  end loop;

  -- Close the file handle
  utl_file.fclose (l_out_file);

Exception
 when l_exc then
   l_error := 'write_blob_to_file : Error - '||l_error;
   p_error := l_error;
 when others then
   l_error := 'write_blob_to_file : Error - '||sqlerrm;
   p_error := l_error;
End write_blob_to_file;
