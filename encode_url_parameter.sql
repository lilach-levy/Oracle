-----------------------------------------------------
-- encode_url_parameter
-----------------------------------------------------
Create or replace function encode_url_parameter ( p_url in varchar2 )
Return varchar2
Is
Begin
  return utl_url.escape(url                   => p_url,
                        escape_reserved_chars => true);
Exception
  when others then
    return null;
End encode_url_parameter;
