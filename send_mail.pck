create or replace package send_mail is

------------------------------------------------------------------------------------
-- Type Definition
------------------------------------------------------------------------------------
TYPE t_rcpt IS  TABLE OF VARCHAR2(240) INDEX BY BINARY_INTEGER;

TYPE Recipient_Table_Type IS TABLE OF VARCHAR2(300) INDEX BY BINARY_INTEGER;

TYPE File_Info_Rec IS RECORD (file_name       varchar2(500),
                              file_type       varchar2(50) default 'text/plain',
                              directory_name  varchar2(500));

TYPE Files_Table_Type IS TABLE OF File_Info_Rec INDEX BY BINARY_INTEGER;

------------------------------------------------------------------------------------
-- send_mail_with_files :
------------------------------------------------------------------------------------
-- Sends e-mail (text or html)
-- to one or more recipients (including cc and/or bcc recipients),
-- with files attachments (text and/or binary; default is text/plain)
------------------------------------------------------------------------------------
-- Parameters :
-- p_from_name    - e-mail address to put in the From field
-- p_to_names     - List of e-mail address to put in To field
-- p_subject      - text string for Subject field
-- p_message      - text string for Message, if any (*)
-- p_html_message - html string for Message, if any (*)
-- (*) you can send  p_message OR p_html_message. default is p_message
-- p_cc_names     - List of e-mail address to put in CC field
--
-- p_files        - List of Attached files,
--                  each record include : file_name
--                                        file_type
--                                        directory_name
--                  (*) file_type :
--                  file_type is the mime type of the file (defaults to 'text/plain')
--                  list of mime type :
--                  text/plain, text/html, image/jpeg, image/gif, application/pdf ,
--                  application/x-excel, application/msword ....
--                  full list of mime types can be seen at:
--                  http://www.webmaster-toolkit.com/mime-types.shtml
--
--                  (*) directory_name :
--                  *  for a text file -
--                     directory is one of the directories in parameter utl_file_dir
--                    (select value from v$parameter where name = 'utl_file_dir')
--                  * for a Mime type , directory is dba_directories
--                   (select * from dba_directories)
------------------------------------------------------------------------------------
procedure send_mail_with_files (p_from_name     in     varchar2,
                                p_to_names      in     Recipient_Table_Type,
                                p_subject       in     varchar2,
                                p_message       in     varchar2  default null,
                                p_html_message  in     varchar2  default null,
                                p_cc_names      in     Recipient_Table_Type,
                                p_files         in     Files_Table_Type,
                                p_error         in out varchar2);


------------------------------------------------------------------------
-- set_dist_list
------------------------------------------------------------------------
--  get list of email adresses seperated by ',' 
--  and return cns_send_mail.Recipient_Table_Type
------------------------------------------------------------------------
Procedure set_dist_list(pv_list   in   varchar2,
                         pt_list   out send_mail.Recipient_Table_Type,
                         p_err_msg out varchar2) ;

end send_mail;
/
create or replace package body send_mail is

----------------------------------------------
-- append_file :
----------------------------------------------
-- Append a file's contents to the e-mail
--
-- directory_name -
--     in oracle version 10g and above : directory is dba_directories
--
--     in oracle version under 10g :
--     (*) for a text file , directory is one of the directories in parameter utl_file_dir
--         (select value from v$parameter where name = 'utl_file_dir')
--     (*) for a Mime type , directory is dba_directories
--         (select * from dba_directories)
----------------------------------------------
procedure append_file ( directory_name in varchar2,
                        file_name      in varchar2,
                        file_type      in varchar2,
                        conn           in out utl_smtp.connection)
is
  file_handle     utl_file.file_type;
  bfile_handle    bfile;
  bfile_len       number;
  pos             number;
  read_bytes      number;
  line            varchar2(32767);
  max_line_size   number := 32767;
  data            raw(200);
  crlf            varchar2(2):= chr(13) || chr(10);
  l_file_len      number;
begin
  -- Open File ...
  -- Mime Type
  if substr(file_type,1,4) != 'text' then
     bfile_handle := bfilename(directory_name,file_name);
     bfile_len   := dbms_lob.getlength(bfile_handle);
     l_file_len := bfile_len;
     pos := 1;
     dbms_lob.open(bfile_handle,dbms_lob.lob_readonly);
  -- Text File
  else
     file_handle := utl_file.fopen(directory_name,file_name,'r',max_line_size);
     l_file_len := 1;
  end if;

  If l_file_len > 0 Then
    -- Read file - Append the file contents to the end of the message ..
    begin
      loop
        -- Mime Type
        if substr(file_type,1,4) != 'text' then
           if pos + 57 - 1 > bfile_len then
              read_bytes := bfile_len - pos + 1;
           else
               read_bytes := 57;
           end if;
           dbms_lob.read(bfile_handle,read_bytes,pos,data);
           utl_smtp.write_raw_data(conn,utl_encode.base64_encode(data));
           pos := pos + 57;
           if pos > bfile_len then
              exit;
           end if;
         -- Text File
         else
            utl_file.get_line(file_handle,line);
            utl_smtp.write_data(conn,line || crlf);
         end if;
      end loop;
    exception
      when no_data_found then Null;
    end;
  End If;

  -- Close the file (binary or text)
  -- Mime Type
  if substr(file_type,1,4) != 'text' then
     dbms_lob.close(bfile_handle);
  else
     utl_file.fclose(file_handle);
  end if;
end append_file;

------------------------------------------------------------------------
-- send_mail_with_files :
------------------------------------------------------------------------
procedure send_mail_with_files (  p_from_name     in     varchar2,
                                  p_to_names      in     Recipient_Table_Type,
                                  p_subject       in     varchar2,
                                  p_message       in     varchar2  default null,
                                  p_html_message  in     varchar2  default null,
                                  p_cc_names      in     Recipient_Table_Type,
                                  p_files         in     Files_Table_Type,
                                  p_error         in out varchar2)
is
   smtp_host          varchar2(256) := fnd_profile.value('CNS_MAIL_IP');
   smtp_port          number        := fnd_profile.value('CNS_MAIL_PORT');

   boundary           constant varchar2(256) := 'CES.Boundary.DACA587499938898';

   crlf               varchar2(2):= chr(13) || chr(10);
   mesg               varchar2(32767);
   conn               UTL_SMTP.CONNECTION;
   i                  binary_integer;

   l_to_list          long;
   l_cc_list          long;

   l_error            varchar2(500);
   l_exc              exception;

begin
   -- open the SMTP connection
   conn := utl_smtp.open_connection(smtp_host,smtp_port);
   utl_smtp.helo(conn,smtp_host);

   -- set From
   utl_smtp.mail(conn,p_from_name);

   -- set To
   if p_to_names.count = 0 then
     l_error := 'p_to_names - Mandatory field';
     raise l_exc;
   end if;

   for i in 1..p_to_names.count loop
      utl_smtp.rcpt(conn,p_to_names(i));
      if l_to_list is null then
        l_to_list := p_to_names(i);
      else
        l_to_list := l_to_list ||','||p_to_names(i);
      end if;
   end loop;

   -- set CC
   for i in 1..p_cc_names.count loop
      utl_smtp.rcpt(conn,p_cc_names(i));

      if l_cc_list is null then
        l_cc_list := p_cc_names(i);
      else
        l_cc_list := l_cc_list ||','||p_cc_names(i);
      end if;
   end loop;

   utl_smtp.open_data(conn);

   -- Build the start of the mail message
   mesg := 
      'From: ' || p_from_name || crlf ||
      'Subject: ' || p_subject || crlf ||
      'To: ' || l_to_list || crlf;
   if l_cc_list is not null then
      mesg := mesg || 'Cc: ' || l_cc_list || crlf;
   end if;
   mesg := mesg || 'Mime-Version: 1.0' || crlf ||
      'Content-Type: multipart/mixed; boundary="' || boundary || '"' ||
      crlf || crlf ||
      'This is a Mime message, which your current mail reader may not' || crlf ||
      'understand. Parts of the message will appear as text. If the remainder' || crlf ||
      'appears as random characters in the message body, instead of as' || crlf ||
      'attachments, then you''ll have to extract these parts and decode them' || crlf ||
      'manually.' || crlf || crlf;
   utl_smtp.write_data(conn,mesg);

   -- Write Message
   if p_message is not null then
      mesg := '--' || boundary || crlf ||
              'Content-Type: text/plain; charset=US-ASCII' ||crlf ||crlf;
      utl_smtp.write_data(conn,mesg);

      utl_smtp.write_data(conn,p_message || crlf);
   end if;

   -- Write the HTML message , If any ..
   if p_html_message is not null then
      mesg := '--' || boundary || crlf ||
              'Content-Type: text/html; charset=US-ASCII' ||crlf ||crlf;
      utl_smtp.write_data(conn,mesg);
      utl_smtp.write_data(conn,p_html_message || crlf);
   end if;

   -- Append Files
   for i in 1..p_files.count loop
       mesg := crlf || '--' || boundary || crlf;
       -- Mime Type
       if substr(p_files(i).file_type,1,4) != 'text' then
            mesg := mesg || 'Content-Type: ' || p_files(i).file_type ||
                    '; name="' || p_files(i).file_name || '"' || crlf ||
                    'Content-Disposition: attachment; filename="' ||
                    p_files(i).file_name || '"' || crlf ||
                    'Content-Transfer-Encoding: base64' || crlf || crlf ;
       -- Text File
       else
           mesg := mesg || 'Content-Type: application/octet-stream; name="' ||
                   p_files(i).file_name || '"' || crlf ||
                   'Content-Disposition: attachment; filename="' ||
                   p_files(i).file_name || '"' || crlf ||
                   'Content-Transfer-Encoding: 7bit' || crlf || crlf ;
       end if;
       utl_smtp.write_data(conn,mesg);

       append_file(p_files(i).directory_name,p_files(i).file_name,p_files(i).file_type,conn);
       utl_smtp.write_data(conn,crlf);
   end loop;

   -- Append the final boundary line
   mesg := crlf || '--' || boundary || '--' || crlf;
   utl_smtp.write_data(conn,mesg);

   -- close the SMTP connection
   utl_smtp.close_data(conn);
   utl_smtp.quit(conn);

exception
  when l_exc then
    l_error := 'send_mail.send_mail_with_files , Error : '||l_error;
    p_error := l_error;
    utl_smtp.quit(conn);
  when others then
    l_error := 'send_mail.send_mail_with_files , Error : '||sqlerrm;
    p_error := l_error;
    utl_smtp.quit(conn);
end send_mail_with_files;

------------------------------------------------------------------------
-- set_dist_list
------------------------------------------------------------------------
Procedure set_dist_list(pv_list   in  varchar2,
                        pt_list   out send_mail.Recipient_Table_Type,
                        p_err_msg out varchar2)
Is
  ln_pos     number;
  lv_address varchar2(300);
  ln_counter number;
Begin
  If pv_list Is Not Null Then
    ln_counter := 1;
    ln_pos     := 1;

    While instr(pv_list, ',', ln_pos) > 1 Loop
      lv_address := substr(pv_list,
                           ln_pos,
                           instr(pv_list, ',', ln_pos) - ln_pos);

      pt_list(ln_counter) := lv_address;
      ln_counter := ln_counter + 1;

      ln_pos := instr(pv_list, ',', ln_pos) + 1;
    End Loop;

    lv_address := substr(pv_list, ln_pos);
    pt_list(ln_counter) := lv_address;
  End If;
Exception
  when others then
     p_err_msg := 'Error on send_mail.set_dist_list : ' || sqlerrm;
End set_dist_list;

end send_mail;
/
