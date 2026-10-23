-- Antes, "confirmar" do salão e do cliente usavam o mesmo status (CONFIRMED). Agora são duas confirmações:
--   salon_confirmed_at    = o salão aceitou o horário
--   customer_confirmed_at = o cliente confirmou que vai
-- Os agendamentos antigos em CONFIRMED viram "aceitos pelo salão" e "confirmados pelo cliente" e voltam a SCHEDULED
-- (a situação do atendimento só muda ao iniciar, finalizar, cancelar ou faltar).
UPDATE appointment
   SET customer_confirmed_at = COALESCE(customer_confirmed_at, created_at),
       salon_confirmed_at    = COALESCE(salon_confirmed_at, created_at),
       status                = 'SCHEDULED'
 WHERE status = 'CONFIRMED';
