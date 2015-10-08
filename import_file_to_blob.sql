-- Create temporary table
create global temporary table LOBS_TMP
(
  BLOB_DATA BLOB
)
on commit delete rows;

-----------------------------------------------------
-- import_file_to_blob
-----------------------------------------------------
create or replace procedure procedure import_file_to_blob ( p_file_name In  varchar2,
                                                            p_directory In  varchar2,
                                                            p_blob      Out blob,
                                                            p_error     Out varchar2)
Is
  lbf_src_file bfile;
BEGIN
  -- open source file
  lbf_src_file := bfilename(directory => p_directory,
                            filename  => p_file_name);

  dbms_lob.fileopen(file_loc  => lbf_src_file,
                    open_mode => dbms_lob.file_readonly);

  insert into lobs_tmp (blob_data)
  values (empty_blob())
  return blob_data into p_blob;

  -- read source file
  dbms_lob.loadfromfile(dest_lob => p_blob,
                        src_lob  => lbf_src_file,
                        amount   => dbms_lob.getlength(lbf_src_file));

  -- close source file
  dbms_lob.fileclose(lbf_src_file);
Exception
    when others THEN
      p_error := 'import_file_to_blob : Error - '||sqlerrm;
End import_file_to_blob;
